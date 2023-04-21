FROM mambaorg/micromamba:0.27.0 AS base

COPY --chown=$MAMBA_USER:$MAMBA_USER environment.conda-lock.yaml /tmp/environment.conda-lock.yaml

RUN micromamba install -n base --yes --file /tmp/environment.conda-lock.yaml && \
    micromamba clean --all --yes

# Otherwise python will not be found
ARG MAMBA_DOCKERFILE_ACTIVATE=1

# Jupyter with Docker Compose
EXPOSE 8888
WORKDIR /home/$MAMBA_USER

FROM base AS dev

COPY --chown=$MAMBA_USER:$MAMBA_USER jupyter_server_config.py /home/$MAMBA_USER/.jupyter/jupyter_server_config.py
# Legacy for Jupyter Notebook Server, see: [#1205](https://github.com/jupyter/docker-stacks/issues/1205)
RUN sed -re "s/c.ServerApp/c.NotebookApp/g" \
    /home/$MAMBA_USER/.jupyter/jupyter_server_config.py > /home/$MAMBA_USER/.jupyter/jupyter_notebook_config.py

ENTRYPOINT ["/usr/local/bin/_entrypoint.sh", "jupyter", "lab", "--ip=0.0.0.0","--allow-root", "--no-browser"]
