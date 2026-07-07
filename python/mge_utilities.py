"""
MGE-Sift Pipeline Utilities
Object-oriented utilities for pipeline orchestration and data processing
"""

import os
import json
import logging
import subprocess
from pathlib import Path
from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from datetime import datetime
import sqlite3
from enum import Enum

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================


class LogLevel(Enum):
    DEBUG = logging.DEBUG
    INFO = logging.INFO
    WARNING = logging.WARNING
    ERROR = logging.ERROR


def get_logger(name: str, level: LogLevel = LogLevel.INFO) -> logging.Logger:
    """Get or create a configured logger instance."""
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler()
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.setLevel(level.value)
    return logger


# ============================================================================
# DATA MODELS
# ============================================================================


@dataclass
class Sample:
    """Represents a genomic sample."""

    sample_id: str
    fasta_path: Path
    config_path: Path
    output_dir: Path

    @property
    def name(self) -> str:
        return self.sample_id

    def get_output_subdir(self, stage: str) -> Path:
        """Get output subdirectory for a pipeline stage."""
        subdir = self.output_dir / stage
        subdir.mkdir(parents=True, exist_ok=True)
        return subdir


@dataclass
class AnalysisResult:
    """Represents a single analysis result."""

    sample_id: str
    element_type: str
    element_id: str
    location: str
    confidence: float
    classification: str  # 'acquired' or 'intrinsic'
    metadata: Dict[str, Any]
    timestamp: str = None

    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now().isoformat()

    def to_dict(self) -> Dict:
        return asdict(self)

    def to_tsv_line(self) -> str:
        """Format as TSV line for output."""
        parts = [
            self.sample_id,
            self.element_type,
            self.element_id,
            self.location,
            f"{self.confidence:.4f}",
            self.classification,
            json.dumps(self.metadata),
        ]
        return "\t".join(str(p) for p in parts)


@dataclass
class PipelineConfig:
    """Configuration for pipeline execution."""

    config_file: Path
    max_cpus: int = 4
    max_memory_gb: int = 8
    database_path: Path = None
    output_dir: Path = None

    def load_from_file(self) -> Dict[str, str]:
        """Load configuration from file."""
        config = {}
        if self.config_file.exists():
            with open(self.config_file) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        if "=" in line:
                            key, value = line.split("=", 1)
                            config[key.strip()] = value.strip()
        return config


# ============================================================================
# ABSTRACT BASE CLASSES
# ============================================================================


class PipelineStage(ABC):
    """Base class for pipeline stages."""

    def __init__(self, name: str, logger: logging.Logger = None):
        self.name = name
        self.logger = logger or get_logger(self.__class__.__name__)
        self.results: List[AnalysisResult] = []

    @abstractmethod
    def execute(self, sample: Sample) -> bool:
        """Execute the pipeline stage."""
        pass

    @abstractmethod
    def validate_output(self, output_dir: Path) -> bool:
        """Validate stage output."""
        pass

    def add_result(self, result: AnalysisResult):
        """Add result to results collection."""
        self.results.append(result)

    def get_results(self) -> List[AnalysisResult]:
        """Get all results from this stage."""
        return self.results


class DatabaseManager(ABC):
    """Abstract base for database operations."""

    @abstractmethod
    def connect(self) -> bool:
        pass

    @abstractmethod
    def disconnect(self):
        pass

    @abstractmethod
    def store_result(self, result: AnalysisResult) -> bool:
        pass

    @abstractmethod
    def query_results(self, **filters) -> List[AnalysisResult]:
        pass


# ============================================================================
# CONCRETE IMPLEMENTATIONS
# ============================================================================


class ShellPipelineStage(PipelineStage):
    """Pipeline stage that wraps shell scripts."""

    def __init__(self, name: str, script_path: Path, logger: logging.Logger = None):
        super().__init__(name, logger)
        self.script_path = script_path

    def execute(self, sample: Sample) -> bool:
        """Execute shell script for this stage."""
        if not self.script_path.exists():
            self.logger.error(f"Script not found: {self.script_path}")
            return False

        try:
            cmd = [
                "bash",
                str(self.script_path),
                str(sample.fasta_path),
                sample.sample_id,
                str(sample.config_path),
                str(sample.output_dir),
            ]

            self.logger.info(f"Executing {self.name}: {' '.join(cmd)}")
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            self.logger.info(f"{self.name} completed successfully")
            return True

        except subprocess.CalledProcessError as e:
            self.logger.error(f"{self.name} failed: {e.stderr}")
            return False

    def validate_output(self, output_dir: Path) -> bool:
        """Validate that stage produced output files."""
        expected_files = list(output_dir.glob(f"*_{self.name.lower()}.*"))
        if expected_files:
            self.logger.info(
                f"Validation passed: found {len(expected_files)} output files"
            )
            return True
        else:
            self.logger.warning(
                f"Validation warning: no output files found for {self.name}"
            )
            return False


class SQLiteDatabaseManager(DatabaseManager):
    """SQLite-based database manager for storing results."""

    def __init__(self, db_path: Path, logger: logging.Logger = None):
        self.db_path = db_path
        self.logger = logger or get_logger(self.__class__.__name__)
        self.connection = None

    def connect(self) -> bool:
        """Connect to SQLite database."""
        try:
            self.connection = sqlite3.connect(str(self.db_path))
            self._initialize_schema()
            self.logger.info(f"Connected to database: {self.db_path}")
            return True
        except sqlite3.Error as e:
            self.logger.error(f"Database connection failed: {e}")
            return False

    def disconnect(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
            self.logger.info("Disconnected from database")

    def _initialize_schema(self):
        """Create database schema if it doesn't exist."""
        cursor = self.connection.cursor()

        # Results table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS analysis_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sample_id TEXT NOT NULL,
                element_type TEXT NOT NULL,
                element_id TEXT NOT NULL,
                location TEXT,
                confidence REAL,
                classification TEXT,
                metadata JSON,
                timestamp TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        # Samples table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS samples (
                sample_id TEXT PRIMARY KEY,
                fasta_path TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                status TEXT DEFAULT 'pending'
            )
        """)

        # Pipeline execution log
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS execution_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sample_id TEXT NOT NULL,
                stage_name TEXT NOT NULL,
                status TEXT,
                start_time TIMESTAMP,
                end_time TIMESTAMP,
                error_message TEXT
            )
        """)

        self.connection.commit()

    def store_result(self, result: AnalysisResult) -> bool:
        """Store analysis result in database."""
        try:
            cursor = self.connection.cursor()
            cursor.execute(
                """
                INSERT INTO analysis_results 
                (sample_id, element_type, element_id, location, confidence, classification, metadata, timestamp)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
                (
                    result.sample_id,
                    result.element_type,
                    result.element_id,
                    result.location,
                    result.confidence,
                    result.classification,
                    json.dumps(result.metadata),
                    result.timestamp,
                ),
            )
            self.connection.commit()
            return True
        except sqlite3.Error as e:
            self.logger.error(f"Failed to store result: {e}")
            return False

    def query_results(self, **filters) -> List[AnalysisResult]:
        """Query results from database."""
        cursor = self.connection.cursor()

        # Build WHERE clause
        where_clause = " AND ".join([f"{k} = ?" for k in filters.keys()])
        if where_clause:
            where_clause = f"WHERE {where_clause}"

        query = f"SELECT * FROM analysis_results {where_clause}"
        cursor.execute(query, list(filters.values()))

        results = []
        for row in cursor.fetchall():
            result = AnalysisResult(
                sample_id=row[1],
                element_type=row[2],
                element_id=row[3],
                location=row[4],
                confidence=row[5],
                classification=row[6],
                metadata=json.loads(row[7]),
                timestamp=row[8],
            )
            results.append(result)

        return results


class PipelineOrchestrator:
    """Orchestrates multi-stage pipeline execution."""

    def __init__(self, config: PipelineConfig, logger: logging.Logger = None):
        self.config = config
        self.logger = logger or get_logger(self.__class__.__name__)
        self.stages: Dict[str, PipelineStage] = {}
        self.db_manager: Optional[DatabaseManager] = None

    def add_stage(self, stage: PipelineStage):
        """Add a pipeline stage."""
        self.stages[stage.name] = stage
        self.logger.info(f"Registered stage: {stage.name}")

    def set_database_manager(self, manager: DatabaseManager):
        """Set the database manager."""
        self.db_manager = manager

    def execute_pipeline(self, samples: List[Sample]) -> bool:
        """Execute full pipeline on samples."""
        all_passed = True

        for sample in samples:
            self.logger.info(f"Processing sample: {sample.sample_id}")

            for stage_name, stage in self.stages.items():
                self.logger.info(f"Executing stage: {stage_name}")

                if not stage.execute(sample):
                    self.logger.error(
                        f"Stage {stage_name} failed for {sample.sample_id}"
                    )
                    all_passed = False
                    continue

                # Validate output
                output_dir = sample.get_output_subdir(stage_name)
                if not stage.validate_output(output_dir):
                    self.logger.warning(f"Output validation warning for {stage_name}")

                # Store results if database manager is configured
                if self.db_manager:
                    for result in stage.results:
                        self.db_manager.store_result(result)

        return all_passed


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================


def load_config(config_path: Path) -> Dict[str, str]:
    """Load configuration from file."""
    config = {}
    if config_path.exists():
        with open(config_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    if "=" in line:
                        key, value = line.split("=", 1)
                        config[key.strip()] = value.strip()
    return config


def validate_fasta(fasta_path: Path) -> bool:
    """Validate FASTA file format."""
    try:
        with open(fasta_path) as f:
            first_line = f.readline().strip()
            if not first_line.startswith(">"):
                return False
            return True
    except Exception:
        return False


def get_execution_stats(results: List[AnalysisResult]) -> Dict[str, Any]:
    """Calculate statistics from analysis results."""
    stats = {
        "total_elements": len(results),
        "element_types": {},
        "avg_confidence": 0.0,
        "classifications": {"acquired": 0, "intrinsic": 0},
    }

    if results:
        confidences = []
        for result in results:
            # Count by type
            et = result.element_type
            stats["element_types"][et] = stats["element_types"].get(et, 0) + 1
            confidences.append(result.confidence)

            # Count classifications
            stats["classifications"][result.classification] += 1

        stats["avg_confidence"] = (
            sum(confidences) / len(confidences) if confidences else 0.0
        )

    return stats


if __name__ == "__main__":
    # Example usage
    logger = get_logger(__name__)
    logger.info("MGE-Sift utilities module loaded")
