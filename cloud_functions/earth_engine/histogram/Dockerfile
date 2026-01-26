# Earth Engine Histogram Lambda - Python 3.13
FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.13

WORKDIR /tmp

# Upgrade pip
RUN python -m pip install pip -U

# Copy and install requirements
COPY requirements.txt ./
RUN python -m pip install -r requirements.txt -t ${LAMBDA_TASK_ROOT}

# Copy shared utilities (copied by CI workflow before build)
COPY shared ${LAMBDA_TASK_ROOT}/shared/

# Copy handler
COPY app.py ${LAMBDA_TASK_ROOT}/

# Reduce package size
RUN cd ${LAMBDA_TASK_ROOT} && find . -type f -name '*.pyc' | while read f; do n=$(echo $f | sed 's/__pycache__\///' | sed 's/.cpython-[0-9]*//'); cp $f $n; done;
RUN cd ${LAMBDA_TASK_ROOT} && find . -type d -a -name '__pycache__' -print0 | xargs -0 rm -rf
RUN find ${LAMBDA_TASK_ROOT} -type d -a -name 'tests' -print0 | xargs -0 rm -rf
RUN rm -rdf ${LAMBDA_TASK_ROOT}/boto3* ${LAMBDA_TASK_ROOT}/botocore* 2>/dev/null || true

WORKDIR ${LAMBDA_TASK_ROOT}

# Verify the build
RUN python -c "from app import handler; print('Histogram Lambda build successful')"

CMD ["app.handler"]
