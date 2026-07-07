"""
MGE-Sift Testing Framework
Unit tests, integration tests, and performance benchmarks
"""

import pytest
import json
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime
import tempfile
import sqlite3

# Import modules to test
import sys
sys.path.insert(0, str(Path(__file__).parent.parent / 'python'))

from mge_utilities import (
    Sample,
    AnalysisResult,
    PipelineConfig,
    ShellPipelineStage,
    SQLiteDatabaseManager,
    PipelineOrchestrator,
    get_logger,
    load_config,
    validate_fasta,
    get_execution_stats,
    LogLevel
)


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def temp_dir():
    """Create temporary directory for tests."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def sample_config(temp_dir):
    """Create test configuration."""
    config_file = temp_dir / "test.cfg"
    config_file.write_text("""
# Test configuration
CONDA_PATH=/opt/conda
CONDA_ENV=mge_pipeline
DATABASE_PATH=/tmp/test.db
""")
    return PipelineConfig(config_file=config_file)


@pytest.fixture
def test_fasta(temp_dir):
    """Create test FASTA file."""
    fasta_file = temp_dir / "test.fasta"
    fasta_file.write_text(">contig_1\n"
"ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG\n"
">contig_2\n"
"GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA\n")
    return fasta_file


@pytest.fixture
def test_sample(temp_dir, test_fasta, sample_config):
    """Create test sample object."""
    output_dir = temp_dir / "output"
    output_dir.mkdir()
    return Sample(
        sample_id="test_sample_001",
        fasta_path=test_fasta,
        config_path=sample_config.config_file,
        output_dir=output_dir
    )


@pytest.fixture
def test_db(temp_dir):
    """Create test database."""
    db_path = temp_dir / "test.db"
    manager = SQLiteDatabaseManager(db_path)
    manager.connect()
    yield manager
    manager.disconnect()


# ============================================================================
# UNIT TESTS - DATA MODELS
# ============================================================================

class TestSample:
    """Test Sample data model."""
    
    def test_sample_creation(self, test_sample):
        """Test sample object creation."""
        assert test_sample.sample_id == "test_sample_001"
        assert test_sample.name == "test_sample_001"
        assert test_sample.fasta_path.exists()
    
    def test_sample_output_subdir(self, test_sample):
        """Test output subdirectory creation."""
        subdir = test_sample.get_output_subdir("annotation")
        assert subdir.exists()
        assert subdir.name == "annotation"


class TestAnalysisResult:
    """Test AnalysisResult data model."""
    
    def test_result_creation(self):
        """Test analysis result creation."""
        result = AnalysisResult(
            sample_id="test_001",
            element_type="plasmid",
            element_id="pABC123",
            location="10000-20000",
            confidence=0.95,
            classification="acquired",
            metadata={"notes": "test"}
        )
        assert result.sample_id == "test_001"
        assert result.confidence == 0.95
        assert result.timestamp is not None
    
    def test_result_to_dict(self):
        """Test result conversion to dict."""
        result = AnalysisResult(
            sample_id="test_001",
            element_type="prophage",
            element_id="php001",
            location="30000-40000",
            confidence=0.87,
            classification="intrinsic",
            metadata={}
        )
        result_dict = result.to_dict()
        assert result_dict['sample_id'] == "test_001"
        assert result_dict['element_type'] == "prophage"
    
    def test_result_tsv_output(self):
        """Test TSV line formatting."""
        result = AnalysisResult(
            sample_id="test_001",
            element_type="is_element",
            element_id="ise001",
            location="50000-51000",
            confidence=0.72,
            classification="acquired",
            metadata={"family": "IS200"}
        )
        tsv_line = result.to_tsv_line()
        assert "test_001" in tsv_line
        assert "is_element" in tsv_line
        assert "0.7200" in tsv_line


class TestPipelineConfig:
    """Test PipelineConfig class."""
    
    def test_config_loading(self, sample_config):
        """Test configuration file loading."""
        config = sample_config.load_from_file()
        assert "CONDA_PATH" in config
        assert config["CONDA_ENV"] == "mge_pipeline"
    
    def test_config_defaults(self, temp_dir):
        """Test default configuration values."""
        empty_config = temp_dir / "empty.cfg"
        empty_config.write_text("")
        config = PipelineConfig(config_file=empty_config)
        assert config.max_cpus == 4
        assert config.max_memory_gb == 8


# ============================================================================
# UNIT TESTS - DATABASE OPERATIONS
# ============================================================================

class TestSQLiteDatabaseManager:
    """Test SQLite database manager."""
    
    def test_database_connection(self, test_db):
        """Test database connection."""
        assert test_db.connection is not None
    
    def test_store_result(self, test_db):
        """Test storing analysis result."""
        result = AnalysisResult(
            sample_id="test_001",
            element_type="plasmid",
            element_id="p001",
            location="1000-2000",
            confidence=0.95,
            classification="acquired",
            metadata={}
        )
        
        assert test_db.store_result(result) is True
    
    def test_query_results(self, test_db):
        """Test querying results from database."""
        # Insert test data
        result1 = AnalysisResult(
            sample_id="test_001",
            element_type="plasmid",
            element_id="p001",
            location="1000-2000",
            confidence=0.95,
            classification="acquired",
            metadata={}
        )
        result2 = AnalysisResult(
            sample_id="test_002",
            element_type="prophage",
            element_id="ph001",
            location="5000-6000",
            confidence=0.85,
            classification="intrinsic",
            metadata={}
        )
        
        test_db.store_result(result1)
        test_db.store_result(result2)
        
        # Query
        results = test_db.query_results(sample_id="test_001")
        assert len(results) == 1
        assert results[0].element_type == "plasmid"


# ============================================================================
# UNIT TESTS - PIPELINE STAGES
# ============================================================================

class TestShellPipelineStage:
    """Test shell-based pipeline stage."""
    
    @patch('subprocess.run')
    def test_stage_execution_success(self, mock_run, test_sample):
        """Test successful stage execution."""
        mock_run.return_value = Mock(returncode=0, stdout="", stderr="")
        
        stage = ShellPipelineStage(
            name="annotation",
            script_path=Path(__file__)
        )
        
        result = stage.execute(test_sample)
        assert result is True
    
    @patch('subprocess.run')
    def test_stage_execution_failure(self, mock_run, test_sample):
        """Test failed stage execution."""
        mock_run.side_effect = Exception("Script failed")
        
        stage = ShellPipelineStage(
            name="annotation",
            script_path=Path("/nonexistent/script.sh")
        )
        
        result = stage.execute(test_sample)
        assert result is False


# ============================================================================
# UNIT TESTS - UTILITY FUNCTIONS
# ============================================================================

class TestUtilityFunctions:
    """Test utility functions."""
    
    def test_validate_fasta_valid(self, test_fasta):
        """Test FASTA validation with valid file."""
        assert validate_fasta(test_fasta) is True
    
    def test_validate_fasta_invalid(self, temp_dir):
        """Test FASTA validation with invalid file."""
        invalid_fasta = temp_dir / "invalid.fasta"
        invalid_fasta.write_text("Not a FASTA file")
        assert validate_fasta(invalid_fasta) is False
    
    def test_get_execution_stats(self):
        """Test execution statistics calculation."""
        results = [
            AnalysisResult("s1", "plasmid", "p1", "1-100", 0.95, "acquired", {}),
            AnalysisResult("s1", "prophage", "ph1", "200-300", 0.85, "intrinsic", {}),
            AnalysisResult("s1", "plasmid", "p2", "400-500", 0.92, "acquired", {}),
        ]
        
        stats = get_execution_stats(results)
        assert stats['total_elements'] == 3
        assert stats['element_types']['plasmid'] == 2
        assert stats['element_types']['prophage'] == 1
        assert stats['classifications']['acquired'] == 2
        assert stats['avg_confidence'] == pytest.approx(0.906, abs=0.01)


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

class TestPipelineOrchestrator:
    """Test pipeline orchestrator integration."""
    
    def test_orchestrator_creation(self, sample_config):
        """Test orchestrator initialization."""
        orchestrator = PipelineOrchestrator(sample_config)
        assert orchestrator.config == sample_config
        assert len(orchestrator.stages) == 0
    
    def test_add_stage(self, sample_config):
        """Test adding stages to orchestrator."""
        orchestrator = PipelineOrchestrator(sample_config)
        stage = ShellPipelineStage("annotation", Path("/fake.sh"))
        
        orchestrator.add_stage(stage)
        assert "annotation" in orchestrator.stages


# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

class TestPerformance:
    """Performance and benchmarking tests."""
    
    def test_database_bulk_insert_performance(self, test_db):
        """Test performance of bulk inserts."""
        results = [
            AnalysisResult(
                f"sample_{i}",
                "plasmid" if i % 2 == 0 else "prophage",
                f"element_{i}",
                f"{i*1000}-{i*1000+1000}",
                0.5 + (i % 50) / 100,
                "acquired" if i % 2 == 0 else "intrinsic",
                {}
            )
            for i in range(100)
        ]
        
        import time
        start = time.time()
        for result in results:
            test_db.store_result(result)
        duration = time.time() - start
        
        # Should complete reasonably fast
        assert duration < 10.0  # 100 inserts in less than 10 seconds


# ============================================================================
# TEST RUNNER
# ============================================================================

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
