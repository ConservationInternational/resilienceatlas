# Use official AWS Lambda Python 3.12 image (Amazon Linux 2023 - glibc 2.34)
# This matches the upstream TiTiler deployment approach
FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.14

WORKDIR /tmp

# Install system dependencies for compiling native extensions
RUN dnf install -y gcc-c++ && dnf clean all

# Upgrade pip
RUN python -m pip install pip -U

COPY requirements.txt ./

# Install dependencies to /asset directory
# Use --no-binary pydantic for better performance
RUN python -m pip install -r requirements.txt -t /asset --no-binary pydantic

# Reduce package size - compile .pyc files and remove source
RUN cd /asset && find . -type f -name '*.pyc' | while read f; do n=$(echo $f | sed 's/__pycache__\///' | sed 's/.cpython-[0-9]*//'); cp $f $n; done;
RUN cd /asset && find . -type d -a -name '__pycache__' -print0 | xargs -0 rm -rf
RUN cd /asset && find . -type f -a -name '*.py' -print0 | xargs -0 rm -f
RUN cd /asset && find . -type f -name '*.so*' -not -path "*/numpy.libs/*" -exec strip --strip-unneeded {} \; 2>/dev/null || true
RUN find /asset -type d -a -name 'tests' -print0 | xargs -0 rm -rf
RUN rm -rdf /asset/numpy/doc/ /asset/boto3* /asset/botocore* /asset/bin /asset/geos_license /asset/Misc

# Copy handler
COPY app.py /asset/handler.py

# Copy required system library (ref: https://github.com/developmentseed/titiler/discussions/1108)
RUN cp /usr/lib64/libexpat.so.1 /asset/

WORKDIR /asset

# Verify the build works
RUN python -c "from handler import handler; print('TiTiler Lambda build successful')"

# Set the handler for AWS Lambda
# The entrypoint from the base image expects: handler.handler
CMD ["handler.handler"]
