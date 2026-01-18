# COG Conversion Lambda - GDAL 3.9 Container Image
# Uses AWS Lambda Python runtime with latest GDAL for native COG driver

FROM ghcr.io/osgeo/gdal:ubuntu-small-3.9.3 AS gdal-base

FROM public.ecr.aws/lambda/python:3.12

# Copy GDAL from osgeo image
COPY --from=gdal-base /usr/bin/gdal* /usr/local/bin/
COPY --from=gdal-base /usr/bin/ogr* /usr/local/bin/
COPY --from=gdal-base /usr/lib/libgdal* /usr/lib/
COPY --from=gdal-base /usr/lib/x86_64-linux-gnu/libgdal* /usr/lib/x86_64-linux-gnu/
COPY --from=gdal-base /usr/lib/x86_64-linux-gnu/libproj* /usr/lib/x86_64-linux-gnu/
COPY --from=gdal-base /usr/lib/x86_64-linux-gnu/libgeos* /usr/lib/x86_64-linux-gnu/
COPY --from=gdal-base /usr/lib/x86_64-linux-gnu/libtiff* /usr/lib/x86_64-linux-gnu/
COPY --from=gdal-base /usr/lib/x86_64-linux-gnu/libgeotiff* /usr/lib/x86_64-linux-gnu/
COPY --from=gdal-base /usr/lib/x86_64-linux-gnu/libsqlite3* /usr/lib/x86_64-linux-gnu/
COPY --from=gdal-base /usr/share/gdal /usr/share/gdal
COPY --from=gdal-base /usr/share/proj /usr/share/proj

# Set GDAL environment
ENV GDAL_DATA=/usr/share/gdal
ENV PROJ_LIB=/usr/share/proj
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# Install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy function code
COPY handler.py ${LAMBDA_TASK_ROOT}/

# Set the CMD to the handler
CMD [ "handler.lambda_handler" ]
