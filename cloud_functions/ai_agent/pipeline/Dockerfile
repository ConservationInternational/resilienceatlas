# Pipeline Lambda — Python 3.14
FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.14

WORKDIR /tmp
RUN python -m pip install pip -U
COPY requirements.txt ./
RUN python -m pip install -r requirements.txt -t ${LAMBDA_TASK_ROOT}
COPY app.py ${LAMBDA_TASK_ROOT}/
WORKDIR ${LAMBDA_TASK_ROOT}
RUN BEDROCK_AGENT_ID=placeholder \
    BEDROCK_AGENT_ALIAS_ID=placeholder \
    python -c "from app import handler; print('pipeline build OK')"
CMD ["app.handler"]
