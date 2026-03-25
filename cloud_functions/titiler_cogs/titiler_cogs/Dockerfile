# Use official AWS Lambda Python 3.14 image (Amazon Linux 2023 - glibc 2.34)
# This matches the upstream TiTiler deployment approach
FROM --platform=linux/amd64 public.ecr.aws/lambda/python:3.14

WORKDIR /tmp

# Install system dependencies for compiling native extensions
RUN dnf install -y gcc-c++ && dnf clean all

# Upgrade pip
RUN python -m pip install pip -U

COPY requirements.txt ./

# Install dependencies directly to Lambda task root
# Use --no-binary pydantic for better performance
RUN python -m pip install -r requirements.txt -t ${LAMBDA_TASK_ROOT} --no-binary pydantic

# Reduce package size - use Python for cleanup since findutils may not be in minimal lambda images
RUN python -c '\
import pathlib, shutil, re, subprocess, os; \
root = pathlib.Path(os.environ["LAMBDA_TASK_ROOT"]); \
[shutil.copy2(pyc, dest) for pyc in sorted(root.rglob("*.pyc"), key=lambda p: len(p.parts)) if not (dest := pyc.parent.parent / (re.sub(r".cpython-[0-9]+", "", pyc.stem) + ".pyc")).exists()]; \
[shutil.rmtree(p, ignore_errors=True) for p in sorted(root.rglob("__pycache__"), key=lambda p: -len(str(p)))]; \
[p.unlink(missing_ok=True) for p in list(root.rglob("*.py"))]; \
[subprocess.run(["strip", "--strip-unneeded", str(p)], capture_output=True) for p in list(root.rglob("*.so*")) if "numpy.libs" not in str(p)]; \
[shutil.rmtree(p, ignore_errors=True) for p in list(root.rglob("tests")) if p.is_dir()]; \
[(shutil.rmtree(p, ignore_errors=True) if p.is_dir() else p.unlink(missing_ok=True)) for pat in ["numpy/doc", "boto3*", "botocore*", "bin", "geos_license", "Misc"] for p in root.glob(pat)]'

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
