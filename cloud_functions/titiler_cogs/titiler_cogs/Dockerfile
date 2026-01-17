# Use lambgeo GDAL image which includes pre-built GDAL and compatible rasterio wheels
FROM ghcr.io/lambgeo/lambda-gdal:3.8-python3.11

WORKDIR ${LAMBDA_TASK_ROOT}

COPY requirements.txt ./

# Install dependencies - rasterio wheels from lambgeo are compatible with this image
RUN python -m pip install --no-cache-dir -r requirements.txt -t .

COPY app.py ./

# Command can be overwritten by providing a different command in the template directly.
CMD ["app.handler"]
