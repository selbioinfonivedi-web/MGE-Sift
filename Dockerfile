FROM mambaorg/micromamba:1.5.8

USER root
RUN apt-get update && apt-get install -y bash procps curl git wget bzip2 ca-certificates && rm -rf /var/lib/apt/lists/*

COPY environment.yml /tmp/environment.yml
RUN micromamba create -y -f /tmp/environment.yml -n mge_pipeline && \
    echo 'source /opt/conda/etc/profile.d/conda.sh && conda activate mge_pipeline' > /opt/conda/etc/profile.d/activate-mge.sh

ENV PATH=/opt/conda/envs/mge_pipeline/bin:/opt/conda/bin:$PATH
WORKDIR /workspace
COPY . /workspace

ENTRYPOINT ["/bin/bash"]
