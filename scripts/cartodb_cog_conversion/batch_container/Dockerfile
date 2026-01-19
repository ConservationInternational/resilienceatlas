# COG Conversion - AWS Batch Container Image
# Uses GDAL 3.9 for native COG driver support

FROM ghcr.io/osgeo/gdal:ubuntu-small-3.9.3

# Install Python dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir --break-system-packages boto3

# Create working directory
WORKDIR /app

# Copy handler script
COPY batch_handler.py /app/

# Set environment variables
ENV GDAL_CACHEMAX=512
ENV GDAL_DATA=/usr/share/gdal
ENV PROJ_LIB=/usr/share/proj

# Run the batch handler
ENTRYPOINT [ "python3", "/app/batch_handler.py" ]
