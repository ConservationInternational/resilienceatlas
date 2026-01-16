FROM public.ecr.aws/lambda/python:3.11

COPY requirements.txt ./

# Use binary wheels only for numpy to avoid compilation issues
RUN python3.11 -m pip install --only-binary=numpy -r requirements.txt -t .

COPY app.py ./

# Command can be overwritten by providing a different command in the template directly.
CMD ["app.handler"]
