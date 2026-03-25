# Earth Engine Histogram Lambda - Python 3.14
FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.14

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

# Reduce package size - use Python for cleanup since findutils may not be in minimal lambda images
RUN python -c "
import pathlib, shutil
root = pathlib.Path('${LAMBDA_TASK_ROOT}')
for p in root.rglob('__pycache__'):
    shutil.rmtree(p, ignore_errors=True)
for p in root.rglob('tests'):
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)
for p in root.glob('boto3*'):
    shutil.rmtree(p, ignore_errors=True) if p.is_dir() else p.unlink(missing_ok=True)
for p in root.glob('botocore*'):
    shutil.rmtree(p, ignore_errors=True) if p.is_dir() else p.unlink(missing_ok=True)
"

WORKDIR ${LAMBDA_TASK_ROOT}

# Verify the build
RUN python -c "from app import handler; print('Histogram Lambda build successful')"

CMD ["app.handler"]
