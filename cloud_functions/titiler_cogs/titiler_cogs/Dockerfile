# Use official AWS Lambda Python 3.13 image (Amazon Linux 2023 - glibc 2.34)
# This matches the upstream TiTiler deployment approach
FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.13

WORKDIR /tmp

# Install system dependencies for compiling native extensions
RUN dnf install -y gcc-c++ && dnf clean all

# Upgrade pip
RUN python -m pip install pip -U

COPY requirements.txt ./

# Install dependencies directly to Lambda task root
# Use --no-binary pydantic for better performance
RUN python -m pip install -r requirements.txt -t ${LAMBDA_TASK_ROOT} --no-binary pydantic

# Reduce package size - compile .pyc files and remove source
RUN cd ${LAMBDA_TASK_ROOT} && find . -type f -name '*.pyc' | while read f; do n=$(echo $f | sed 's/__pycache__\///' | sed 's/.cpython-[0-9]*//'); cp $f $n; done;
RUN cd ${LAMBDA_TASK_ROOT} && find . -type d -a -name '__pycache__' -print0 | xargs -0 rm -rf
RUN cd ${LAMBDA_TASK_ROOT} && find . -type f -a -name '*.py' -print0 | xargs -0 rm -f
RUN cd ${LAMBDA_TASK_ROOT} && find . -type f -name '*.so*' -not -path "*/numpy.libs/*" -exec strip --strip-unneeded {} \; 2>/dev/null || true
RUN find ${LAMBDA_TASK_ROOT} -type d -a -name 'tests' -print0 | xargs -0 rm -rf
RUN rm -rdf ${LAMBDA_TASK_ROOT}/numpy/doc/ ${LAMBDA_TASK_ROOT}/boto3* ${LAMBDA_TASK_ROOT}/botocore* ${LAMBDA_TASK_ROOT}/bin ${LAMBDA_TASK_ROOT}/geos_license ${LAMBDA_TASK_ROOT}/Misc

# Copy handler
COPY app.py ${LAMBDA_TASK_ROOT}/handler.py

# Copy required system library (ref: https://github.com/developmentseed/titiler/discussions/1108)
RUN cp /usr/lib64/libexpat.so.1 ${LAMBDA_TASK_ROOT}/

WORKDIR ${LAMBDA_TASK_ROOT}

# Verify the build works
RUN python -c "from handler import handler; print('TiTiler Lambda build successful')"

# Set the handler for AWS Lambda
# The entrypoint from the base image expects: handler.handler
CMD ["handler.handler"]
