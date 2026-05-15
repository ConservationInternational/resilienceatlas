# Earth Engine Raster Interaction Lambda - Python 3.14
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
RUN python -c '\
import pathlib, shutil, os; \
root = pathlib.Path(os.environ["LAMBDA_TASK_ROOT"]); \
[shutil.rmtree(p, ignore_errors=True) for p in list(root.rglob("__pycache__"))]; \
[shutil.rmtree(p, ignore_errors=True) for p in list(root.rglob("tests")) if p.is_dir()]; \
[(shutil.rmtree(p, ignore_errors=True) if p.is_dir() else p.unlink(missing_ok=True)) for p in list(root.glob("boto3*")) + list(root.glob("botocore*"))]'

WORKDIR ${LAMBDA_TASK_ROOT}

# Verify the build
RUN python -c "from app import handler; print('Raster Interaction Lambda build successful')"

CMD ["app.handler"]
