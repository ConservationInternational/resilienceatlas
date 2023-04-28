import logging
import os
from pathlib import Path
import pickle
from typing import Literal
import requests
import subprocess
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import boto3

# Google Sheets API setup
SCOPES = ["https://www.googleapis.com/auth/spreadsheets.readonly"]
SPREADSHEET_ID = "your_spreadsheet_id"
RANGE_NAME = "Sheet1!A1:B"

# AWS S3 setup
s3 = boto3.client("s3")


# Read inputs from Google Sheet
def read_inputs():
    creds = None
    if os.path.exists("token.pickle"):
        with open("token.pickle", "rb") as token:
            creds = pickle.load(token)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file("credentials.json", SCOPES)
            creds = flow.run_local_server(port=0)

        with open("token.pickle", "wb") as token:
            pickle.dump(creds, token)

    service = build("sheets", "v4", credentials=creds)

    result = (
        service.spreadsheets()
        .values()
        .get(spreadsheetId=SPREADSHEET_ID, range=RANGE_NAME)
        .execute()
    )
    values = result.get("values", [])
    if not values:
        logging.warning(f"No data found.")
    else:
        logging.warning(f"Data found.")
    return values


# Download TIFF file
def download_tiff(url, local_path):
    response = requests.get(url, stream=True)
    with open(local_path, "wb") as f:
        for chunk in response.iter_content(chunk_size=1024):
            if chunk:
                f.write(chunk)


def create_overviews(
    input_file: Path,
    operation: Literal[
        "nearest",
        "average",
        "rms",
        "gauss",
        "cubic",
        "cubicspline",
        "lanczos",
        "average_magphase",
        "mode",
    ] = "nearest",
):
    cmd = ["gdaladdo", "-clean" "-r", operation, input_file.as_posix()]
    subprocess.run(cmd, check=True)


def transform_cog(input_file: Path, output_file: Path):
    cmd = [
        "gdal_translate",
        input_file.as_posix(),
        output_file.as_posix(),
        "of=COG",
        "TILING_SCHEME=GoogleMapsCompatible",
        "-co",
        "COMPRESS=LZW",
        "-co",
        "TILED=YES",
        "-co",
        "COPY_SRC_OVERVIEWS=YES",
    ]
    subprocess.run(cmd, check=True)


# Upload COG file to S3
def upload_cog(local_path: Path, bucket, key):
    s3.upload_file(local_path, bucket, key)


def process_file(
    bucket: str,
    input_file: Path,
    output_file: Path,
    operation: Literal[
        "nearest",
        "average",
        "rms",
        "gauss",
        "cubic",
        "cubicspline",
        "lanczos",
        "average_magphase",
        "mode",
    ],
):
    input_url = f"https://{bucket}.s3.amazonaws.com/{input_file}"
    local_input_file = "/tmp/input.tif"
    local_output_file = "/tmp/output.tif"

    download_tiff(input_url, local_input_file)
    create_overviews(local_input_file, operation)
    transform_cog(local_input_file, local_output_file)
    upload_cog(local_output_file, bucket, output_file)

    os.remove(local_input_file)
    os.remove(local_output_file)


# Process TIFF files


def process_tiff_files():
    inputs = read_inputs()
    for bucket, input_file, output_file, operation in inputs:
        input_file = Path(input_file)
        if not input_file or input_file.exists() or input_file.suffix != ".tif":
            logging.warning("Could not find file: %s" % input_file)
            continue

        process_file(bucket, input_file, output_file, operation)


if __name__ == "__main__":
    process_tiff_files()
