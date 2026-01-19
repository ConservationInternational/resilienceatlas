#!/usr/bin/env python3
"""
COG Conversion Manager

Lists raw TIFFs in S3, checks which have been converted to COGs,
and invokes Lambda to convert the remaining ones.

Usage:
    python manage_cog_conversion.py list       - List all raw TIFFs
    python manage_cog_conversion.py status     - Show conversion status
    python manage_cog_conversion.py convert    - Convert pending TIFFs
    python manage_cog_conversion.py convert-one <key>  - Convert a single TIFF
    python manage_cog_conversion.py deploy     - Deploy Lambda function
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

try:
    import boto3
    from botocore.config import Config
except ImportError:
    print("ERROR: boto3 is required. Install with: pip install boto3")
    sys.exit(1)


# =============================================================================
# Configuration
# =============================================================================

class Config:
    """Configuration settings with environment variable overrides."""
    
    def __init__(self):
        # S3 configuration
        self.s3_bucket = os.environ.get("S3_BUCKET", "")
        self.source_prefix = os.environ.get("SOURCE_PREFIX", "cartodb_exports/rasters/")
        self.cog_prefix = os.environ.get("COG_PREFIX", "cartodb_exports/cogs/")
        self.aws_region = os.environ.get("AWS_REGION", "us-east-1")
        self.aws_profile = os.environ.get("AWS_PROFILE", "")
        
        # Lambda configuration
        self.lambda_function_name = os.environ.get("LAMBDA_FUNCTION_NAME", "cog-converter")
        self.ecr_repo_name = os.environ.get("ECR_REPO_NAME", "cog-converter")
        self.lambda_memory = int(os.environ.get("LAMBDA_MEMORY", "3008"))
        self.lambda_timeout = int(os.environ.get("LAMBDA_TIMEOUT", "900"))
        
        # Processing options
        self.batch_size = int(os.environ.get("BATCH_SIZE", "10"))
        self.compression = os.environ.get("COMPRESSION", "LZW")
        self.parallel_invocations = int(os.environ.get("PARALLEL_INVOCATIONS", "5"))
        self.overwrite = os.environ.get("OVERWRITE", "false").lower() == "true"
        self.filename_filter = os.environ.get("FILENAME_FILTER", "")
        self.dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"
        
        # Local directories
        self.script_dir = Path(__file__).parent.resolve()
        self.output_dir = Path(os.environ.get("OUTPUT_DIR", self.script_dir / "cog_status"))
        self.lambda_dir = self.script_dir / "lambda_function"
        
        # Ensure output directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Status files
        self.tiff_list = self.output_dir / "raw_tiffs.txt"
        self.cog_list = self.output_dir / "existing_cogs.txt"
        self.pending_list = self.output_dir / "pending_conversions.txt"
        self.completed_list = self.output_dir / "completed_conversions.txt"
        self.failed_list = self.output_dir / "failed_conversions.txt"
        self.log_file = self.output_dir / "cog_conversion.log"
    
    def validate(self):
        """Validate required configuration."""
        if not self.s3_bucket:
            print("ERROR: S3_BUCKET environment variable not set")
            print("Usage: S3_BUCKET=your-bucket python manage_cog_conversion.py <command>")
            sys.exit(1)


# =============================================================================
# Logging
# =============================================================================

def log(level: str, message: str, config: Optional[Config] = None):
    """Log a message with timestamp."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {level}: {message}"
    print(line)
    if config and config.log_file:
        with open(config.log_file, "a") as f:
            f.write(line + "\n")

def info(message: str, config: Optional[Config] = None):
    log("INFO", message, config)

def warn(message: str, config: Optional[Config] = None):
    log("WARN", message, config)

def error(message: str, config: Optional[Config] = None):
    log("ERROR", message, config)


# =============================================================================
# AWS Client Factory
# =============================================================================

def get_boto_session(config: Config):
    """Create a boto3 session with optional profile."""
    if config.aws_profile:
        return boto3.Session(profile_name=config.aws_profile, region_name=config.aws_region)
    return boto3.Session(region_name=config.aws_region)

def get_s3_client(config: Config):
    """Get S3 client."""
    session = get_boto_session(config)
    return session.client("s3")

def get_lambda_client(config: Config):
    """Get Lambda client."""
    session = get_boto_session(config)
    return session.client("lambda")

def get_ecr_client(config: Config):
    """Get ECR client."""
    session = get_boto_session(config)
    return session.client("ecr")

def get_iam_client(config: Config):
    """Get IAM client."""
    session = get_boto_session(config)
    return session.client("iam")

def get_sts_client(config: Config):
    """Get STS client."""
    session = get_boto_session(config)
    return session.client("sts")


# =============================================================================
# S3 Listing Functions
# =============================================================================

def list_raw_tiffs(config: Config) -> list[tuple[str, int]]:
    """
    List all raw TIFFs in source prefix.
    
    Returns:
        List of (key, size) tuples
    """
    info(f"Listing raw TIFFs in s3://{config.s3_bucket}/{config.source_prefix}...", config)
    
    s3 = get_s3_client(config)
    tiffs = []
    
    paginator = s3.get_paginator("list_objects_v2")
    page_iterator = paginator.paginate(
        Bucket=config.s3_bucket,
        Prefix=config.source_prefix
    )
    
    # Compile filename filter regex if specified
    filter_regex = None
    if config.filename_filter:
        info(f"Applying filename filter: {config.filename_filter}", config)
        filter_regex = re.compile(config.filename_filter)
    
    for page in page_iterator:
        for obj in page.get("Contents", []):
            key = obj["Key"]
            size = obj["Size"]
            
            # Check if it's a TIFF
            if not key.lower().endswith((".tif", ".tiff")):
                continue
            
            # Apply filename filter
            if filter_regex:
                filename = os.path.basename(key)
                if not filter_regex.search(filename):
                    continue
            
            tiffs.append((key, size))
    
    info(f"Found {len(tiffs)} raw TIFFs{' (filtered)' if filter_regex else ''}", config)
    
    # Save to file
    with open(config.tiff_list, "w") as f:
        for key, size in tiffs:
            f.write(f"{key}\t{size}\n")
    
    return tiffs


def list_existing_cogs(config: Config) -> set[str]:
    """
    List all existing COGs in destination prefix.
    
    Returns:
        Set of COG keys
    """
    info(f"Listing existing COGs in s3://{config.s3_bucket}/{config.cog_prefix}...", config)
    
    s3 = get_s3_client(config)
    cogs = set()
    
    paginator = s3.get_paginator("list_objects_v2")
    page_iterator = paginator.paginate(
        Bucket=config.s3_bucket,
        Prefix=config.cog_prefix
    )
    
    for page in page_iterator:
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.lower().endswith((".tif", ".tiff")):
                cogs.add(key)
    
    info(f"Found {len(cogs)} existing COGs", config)
    
    # Save to file
    with open(config.cog_list, "w") as f:
        for key in sorted(cogs):
            f.write(f"{key}\n")
    
    return cogs


def find_pending_conversions(config: Config, tiffs: list[tuple[str, int]], cogs: set[str]) -> list[tuple[str, int]]:
    """
    Determine which TIFFs need conversion.
    
    Returns:
        List of (source_key, size) tuples for pending conversions
    """
    info("Finding TIFFs pending conversion...", config)
    
    pending = []
    
    for source_key, size in tiffs:
        # Build expected COG key
        filename = os.path.basename(source_key)
        stem = os.path.splitext(filename)[0]
        cog_key = f"{config.cog_prefix}{stem}_cog.tif"
        
        # Check if COG exists
        if cog_key not in cogs or config.overwrite:
            pending.append((source_key, size))
    
    info(f"Found {len(pending)} TIFFs pending conversion", config)
    
    # Save to file
    with open(config.pending_list, "w") as f:
        for key, size in pending:
            f.write(f"{key}\t{size}\n")
    
    return pending


# =============================================================================
# Lambda Management
# =============================================================================

def invoke_lambda(config: Config, source_key: str) -> dict:
    """
    Invoke Lambda to convert a single TIFF.
    
    Returns:
        Lambda response payload
    """
    lambda_client = get_lambda_client(config)
    
    payload = {
        "source_bucket": config.s3_bucket,
        "source_key": source_key,
        "dest_bucket": config.s3_bucket,
        "dest_prefix": config.cog_prefix,
        "compression": config.compression,
        "overwrite": config.overwrite
    }
    
    if config.dry_run:
        info(f"[DRY RUN] Would invoke Lambda for: {source_key}", config)
        return {"dry_run": True, "source_key": source_key}
    
    response = lambda_client.invoke(
        FunctionName=config.lambda_function_name,
        InvocationType="RequestResponse",
        Payload=json.dumps(payload)
    )
    
    result = json.loads(response["Payload"].read())
    return result


def convert_single(config: Config, source_key: str):
    """Convert a single TIFF to COG."""
    info(f"Converting: {source_key}", config)
    
    try:
        result = invoke_lambda(config, source_key)
        
        if config.dry_run:
            return
        
        if result.get("success"):
            info(f"Successfully converted: {source_key} -> {result.get('dest_key')}", config)
            with open(config.completed_list, "a") as f:
                f.write(f"{source_key}\n")
        else:
            error(f"Failed to convert: {source_key} - {result.get('error')}", config)
            with open(config.failed_list, "a") as f:
                f.write(f"{source_key}\t{result.get('error')}\n")
                
    except Exception as e:
        error(f"Lambda invocation failed for {source_key}: {e}", config)
        with open(config.failed_list, "a") as f:
            f.write(f"{source_key}\t{str(e)}\n")


def convert_all(config: Config, pending: list[tuple[str, int]]):
    """Convert all pending TIFFs."""
    if not pending:
        info("No TIFFs pending conversion", config)
        return
    
    total = len(pending)
    info(f"Converting {total} TIFFs...", config)
    
    if config.dry_run:
        info("[DRY RUN] Would convert the following files:", config)
        for source_key, size in pending[:20]:
            print(f"  - {source_key} ({size:,} bytes)")
        if total > 20:
            print(f"  ... and {total - 20} more")
        return
    
    # Clear status files
    config.completed_list.write_text("")
    config.failed_list.write_text("")
    
    completed = 0
    failed = 0
    
    for i, (source_key, size) in enumerate(pending, 1):
        info(f"[{i}/{total}] Converting: {source_key}", config)
        
        try:
            result = invoke_lambda(config, source_key)
            
            if result.get("success"):
                completed += 1
                with open(config.completed_list, "a") as f:
                    f.write(f"{source_key}\n")
            else:
                failed += 1
                error(f"Failed: {result.get('error')}", config)
                with open(config.failed_list, "a") as f:
                    f.write(f"{source_key}\t{result.get('error')}\n")
                    
        except Exception as e:
            failed += 1
            error(f"Lambda error: {e}", config)
            with open(config.failed_list, "a") as f:
                f.write(f"{source_key}\t{str(e)}\n")
        
        # Brief pause between invocations
        if i < total:
            time.sleep(0.1)
    
    info(f"Conversion complete: {completed} succeeded, {failed} failed", config)


# =============================================================================
# Lambda Deployment
# =============================================================================

def get_aws_account_id(config: Config) -> str:
    """Get AWS account ID."""
    sts = get_sts_client(config)
    return sts.get_caller_identity()["Account"]


def ensure_ecr_repo(config: Config) -> str:
    """Ensure ECR repository exists and return URI."""
    ecr = get_ecr_client(config)
    
    try:
        response = ecr.describe_repositories(repositoryNames=[config.ecr_repo_name])
        repo_uri = response["repositories"][0]["repositoryUri"]
        info(f"ECR repository exists: {repo_uri}", config)
        return repo_uri
    except ecr.exceptions.RepositoryNotFoundException:
        info(f"Creating ECR repository: {config.ecr_repo_name}", config)
        response = ecr.create_repository(
            repositoryName=config.ecr_repo_name,
            imageScanningConfiguration={"scanOnPush": True}
        )
        repo_uri = response["repository"]["repositoryUri"]
        info(f"Created ECR repository: {repo_uri}", config)
        return repo_uri


def ensure_lambda_role(config: Config) -> str:
    """Ensure Lambda execution role exists and return ARN."""
    iam = get_iam_client(config)
    role_name = f"{config.lambda_function_name}-role"
    
    try:
        response = iam.get_role(RoleName=role_name)
        role_arn = response["Role"]["Arn"]
        info(f"Lambda role exists: {role_arn}", config)
        return role_arn
    except iam.exceptions.NoSuchEntityException:
        info(f"Creating Lambda role: {role_name}", config)
        
        trust_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }
        
        response = iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description="Lambda execution role for COG converter"
        )
        role_arn = response["Role"]["Arn"]
        
        # Attach policies
        iam.attach_role_policy(
            RoleName=role_name,
            PolicyArn="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        )
        
        # S3 access policy
        s3_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
                "Resource": [
                    f"arn:aws:s3:::{config.s3_bucket}",
                    f"arn:aws:s3:::{config.s3_bucket}/*"
                ]
            }]
        }
        
        iam.put_role_policy(
            RoleName=role_name,
            PolicyName="S3Access",
            PolicyDocument=json.dumps(s3_policy)
        )
        
        info(f"Created Lambda role: {role_arn}", config)
        info("Waiting 10 seconds for role propagation...", config)
        time.sleep(10)
        
        return role_arn


def build_and_push_image(config: Config, repo_uri: str) -> str:
    """Build Docker image and push to ECR."""
    info("Building Docker image...", config)
    
    # Get ECR login
    ecr = get_ecr_client(config)
    auth = ecr.get_authorization_token()
    token = auth["authorizationData"][0]["authorizationToken"]
    registry = auth["authorizationData"][0]["proxyEndpoint"]
    
    # Docker login
    import base64
    decoded = base64.b64decode(token).decode()
    username, password = decoded.split(":")
    
    subprocess.run(
        ["docker", "login", "--username", username, "--password-stdin", registry],
        input=password.encode(),
        check=True,
        capture_output=True
    )
    
    image_tag = f"{repo_uri}:latest"
    
    # Build image
    subprocess.run(
        ["docker", "build", "-t", image_tag, str(config.lambda_dir)],
        check=True
    )
    
    # Push image
    info(f"Pushing image to ECR: {image_tag}", config)
    subprocess.run(["docker", "push", image_tag], check=True)
    
    return image_tag


def deploy_lambda(config: Config):
    """Deploy Lambda function."""
    info("Deploying Lambda function...", config)
    
    if config.dry_run:
        info("[DRY RUN] Would deploy Lambda function", config)
        return
    
    # Ensure ECR repo exists
    repo_uri = ensure_ecr_repo(config)
    
    # Ensure role exists
    role_arn = ensure_lambda_role(config)
    
    # Build and push image
    image_uri = build_and_push_image(config, repo_uri)
    
    # Create or update Lambda
    lambda_client = get_lambda_client(config)
    
    try:
        # Try to update existing function
        lambda_client.update_function_code(
            FunctionName=config.lambda_function_name,
            ImageUri=image_uri
        )
        
        lambda_client.update_function_configuration(
            FunctionName=config.lambda_function_name,
            MemorySize=config.lambda_memory,
            Timeout=config.lambda_timeout,
            Environment={"Variables": {"GDAL_CACHEMAX": "512"}}
        )
        
        info(f"Updated Lambda function: {config.lambda_function_name}", config)
        
    except lambda_client.exceptions.ResourceNotFoundException:
        # Create new function
        lambda_client.create_function(
            FunctionName=config.lambda_function_name,
            Role=role_arn,
            Code={"ImageUri": image_uri},
            PackageType="Image",
            MemorySize=config.lambda_memory,
            Timeout=config.lambda_timeout,
            Environment={"Variables": {"GDAL_CACHEMAX": "512"}}
        )
        
        info(f"Created Lambda function: {config.lambda_function_name}", config)


# =============================================================================
# Commands
# =============================================================================

def cmd_list(config: Config):
    """List all raw TIFFs."""
    tiffs = list_raw_tiffs(config)
    print(len(tiffs))
    print(f"\nRaw TIFFs listed in: {config.tiff_list}")
    print("\nFirst 10 entries:")
    for key, size in tiffs[:10]:
        print(f"  {key}\t{size}")


def cmd_status(config: Config):
    """Show conversion status."""
    tiffs = list_raw_tiffs(config)
    cogs = list_existing_cogs(config)
    pending = find_pending_conversions(config, tiffs, cogs)
    
    total = len(tiffs)
    converted = total - len(pending)
    
    print("\n" + "=" * 60)
    print("COG Conversion Status")
    print("=" * 60)
    print(f"Source:      s3://{config.s3_bucket}/{config.source_prefix}")
    print(f"Destination: s3://{config.s3_bucket}/{config.cog_prefix}")
    print("-" * 60)
    print(f"Total raw TIFFs:      {total:>8}")
    print(f"Existing COGs:        {len(cogs):>8}")
    print(f"Already converted:    {converted:>8}")
    print(f"Pending conversion:   {len(pending):>8}")
    
    if total > 0:
        pct = (converted / total) * 100
        print(f"Progress:             {pct:>7.1f}%")
    
    print("=" * 60)
    
    if pending:
        # Calculate total size
        total_size = sum(size for _, size in pending)
        print(f"\nPending data size: {total_size / (1024**3):.2f} GB")
        print(f"\nPending list saved to: {config.pending_list}")


def cmd_convert(config: Config):
    """Convert pending TIFFs."""
    tiffs = list_raw_tiffs(config)
    cogs = list_existing_cogs(config)
    pending = find_pending_conversions(config, tiffs, cogs)
    convert_all(config, pending)


def cmd_convert_one(config: Config, source_key: str):
    """Convert a single TIFF."""
    convert_single(config, source_key)


def cmd_deploy(config: Config):
    """Deploy Lambda function."""
    deploy_lambda(config)


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="COG Conversion Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Environment Variables:
  S3_BUCKET           S3 bucket name (required)
  SOURCE_PREFIX       Source prefix for raw TIFFs (default: cartodb_exports/rasters/)
  COG_PREFIX          Destination prefix for COGs (default: cartodb_exports/cogs/)
  AWS_REGION          AWS region (default: us-east-1)
  AWS_PROFILE         AWS credentials profile name
  LAMBDA_FUNCTION_NAME  Lambda function name (default: cog-converter)
  FILENAME_FILTER     Regex to filter filenames
  DRY_RUN             Show what would run without executing (true/false)
  OVERWRITE           Overwrite existing COGs (true/false)

Examples:
  S3_BUCKET=my-bucket python manage_cog_conversion.py list
  S3_BUCKET=my-bucket python manage_cog_conversion.py status
  S3_BUCKET=my-bucket DRY_RUN=true python manage_cog_conversion.py convert
  S3_BUCKET=my-bucket python manage_cog_conversion.py convert-one path/to/file.tif
        """
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    subparsers.add_parser("list", help="List all raw TIFFs")
    subparsers.add_parser("status", help="Show conversion status")
    subparsers.add_parser("convert", help="Convert pending TIFFs")
    subparsers.add_parser("deploy", help="Deploy Lambda function")
    
    convert_one_parser = subparsers.add_parser("convert-one", help="Convert a single TIFF")
    convert_one_parser.add_argument("source_key", help="S3 key of the TIFF to convert")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    config = Config()
    config.validate()
    
    if args.command == "list":
        cmd_list(config)
    elif args.command == "status":
        cmd_status(config)
    elif args.command == "convert":
        cmd_convert(config)
    elif args.command == "convert-one":
        cmd_convert_one(config, args.source_key)
    elif args.command == "deploy":
        cmd_deploy(config)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
