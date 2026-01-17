# Use lambgeo GDAL image which includes pre-built GDAL and compatible rasterio wheels
FROM ghcr.io/lambgeo/lambda-gdal:3.8-python3.11

WORKDIR ${LAMBDA_TASK_ROOT}

COPY requirements.txt ./

# Install dependencies - force binary wheels only (no source compilation)
RUN python -m pip install --no-cache-dir --only-binary=:all: -r requirements.txt -t .

COPY app.py ./

# Command can be overwritten by providing a different command in the template directly.
CMD ["app.handler"]
