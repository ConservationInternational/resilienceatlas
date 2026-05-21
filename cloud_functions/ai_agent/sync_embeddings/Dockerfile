# Embedding Sync Lambda — Python 3.14
FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.14

WORKDIR /tmp
RUN python -m pip install pip -U
COPY requirements.txt ./
RUN python -m pip install -r requirements.txt -t ${LAMBDA_TASK_ROOT}
COPY app.py ${LAMBDA_TASK_ROOT}/
WORKDIR ${LAMBDA_TASK_ROOT}
RUN RAILS_API_URL=http://placeholder \
    RESILIENCE_API_KEY=placeholder \
    EMBEDDINGS_BUCKET=placeholder \
    python -c "from app import handler; print('sync_embeddings build OK')"
CMD ["app.handler"]
