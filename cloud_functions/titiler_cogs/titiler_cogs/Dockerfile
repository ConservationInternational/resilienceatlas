FROM public.ecr.aws/lambda/python:3.11

COPY requirements.txt ./

# Install with binary-only for packages that need compilation
RUN python3.11 -m pip install --only-binary=:all: -r requirements.txt -t .

COPY app.py ./

# Command can be overwritten by providing a different command in the template directly.
CMD ["app.handler"]
