#!/usr/bin/env python3
"""
COG Conversion Manager - AWS Batch Version

Lists raw TIFFs in S3, checks which have been converted to COGs,
and submits AWS Batch jobs to convert the remaining ones.

Supports resuming interrupted jobs - already converted files are skipped.

Usage:
    python manage_cog_conversion.py list       - List all raw TIFFs
    python manage_cog_conversion.py status     - Show conversion status
    python manage_cog_conversion.py convert    - Submit batch jobs for pending TIFFs
    python manage_cog_conversion.py jobs       - Show status of batch jobs
    python manage_cog_conversion.py setup      - Set up AWS Batch infrastructure
    python manage_cog_conversion.py deploy     - Build and push Docker image
"""

import argparse
import json
import math
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
    from botocore.exceptions import ClientError
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
        
        # Batch configuration
        self.batch_job_name = os.environ.get("BATCH_JOB_NAME", "cog-converter")
        self.ecr_repo_name = os.environ.get("ECR_REPO_NAME", "cog-converter")
        self.compute_env_name = os.environ.get("COMPUTE_ENV_NAME", "cog-converter-env")
        self.job_queue_name = os.environ.get("JOB_QUEUE_NAME", "cog-converter-queue")
        self.job_definition_name = os.environ.get("JOB_DEFINITION_NAME", "cog-converter-job")
        
        # Processing options
        self.files_per_job = int(os.environ.get("FILES_PER_JOB", "50"))  # Files per batch job
        self.max_vcpus = int(os.environ.get("MAX_VCPUS", "16"))  # Max concurrent vCPUs
        self.job_vcpus = int(os.environ.get("JOB_VCPUS", "2"))  # vCPUs per job
        self.job_memory = int(os.environ.get("JOB_MEMORY", "4096"))  # MB per job
        self.compression = os.environ.get("COMPRESSION", "LZW")
        self.overwrite = os.environ.get("OVERWRITE", "false").lower() == "true"
        self.filename_filter = os.environ.get("FILENAME_FILTER", "")
        # RASTER_TYPE: "public", "cdb_importer", or "both" (default)
        self.raster_type = os.environ.get("RASTER_TYPE", "both").lower()
        self.dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"
        self.use_spot = os.environ.get("USE_SPOT", "true").lower() == "true"
        
        # Local directories
        self.script_dir = Path(__file__).parent.resolve()
        self.output_dir = Path(os.environ.get("OUTPUT_DIR", self.script_dir / "cog_status"))
        self.docker_dir = self.script_dir / "batch_container"
        
        # Ensure output directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Status files
        self.tiff_list = self.output_dir / "raw_tiffs.txt"
        self.cog_list = self.output_dir / "existing_cogs.txt"
        self.pending_list = self.output_dir / "pending_conversions.txt"
        self.jobs_file = self.output_dir / "submitted_jobs.json"
        self.log_file = self.output_dir / "cog_conversion.log"
    
    def validate(self):
        """Validate required configuration."""
        if not self.s3_bucket:
            print("ERROR: S3_BUCKET environment variable not set")
            print("Usage: S3_BUCKET=your-bucket python manage_cog_conversion.py <command>")
            sys.exit(1)
        
        # Ensure source and destination prefixes are different
        source = self.source_prefix.rstrip("/")
        dest = self.cog_prefix.rstrip("/")
        if source == dest:
            print("ERROR: SOURCE_PREFIX and COG_PREFIX must be different")
            print(f"  SOURCE_PREFIX: {self.source_prefix}")
            print(f"  COG_PREFIX: {self.cog_prefix}")
            print("This check prevents accidentally overwriting source files.")
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


def get_batch_client(config: Config):
    """Get Batch client."""
    session = get_boto_session(config)
    return session.client("batch")


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
    
    # Raster type filter
    if config.raster_type != "both":
        info(f"Filtering by raster type: {config.raster_type}", config)
    
    for page in page_iterator:
        for obj in page.get("Contents", []):
            key = obj["Key"]
            size = obj["Size"]
            filename = os.path.basename(key)
            
            # Check if it's a TIFF
            if not key.lower().endswith((".tif", ".tiff")):
                continue
            
            # Apply raster type filter
            if config.raster_type == "public":
                if not filename.startswith("public_"):
                    continue
            elif config.raster_type == "cdb_importer":
                if not filename.startswith("cdb_importer_"):
                    continue
            # "both" accepts all files
            
            # Apply filename filter
            if filter_regex:
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
    
    try:
        page_iterator = paginator.paginate(
            Bucket=config.s3_bucket,
            Prefix=config.cog_prefix
        )
        
        for page in page_iterator:
            for obj in page.get("Contents", []):
                key = obj["Key"]
                if key.lower().endswith((".tif", ".tiff")):
                    cogs.add(key)
    except ClientError as e:
        # Prefix might not exist yet
        if e.response["Error"]["Code"] != "NoSuchKey":
            raise
    
    info(f"Found {len(cogs)} existing COGs", config)
    
    # Save to file
    with open(config.cog_list, "w") as f:
        for key in sorted(cogs):
            f.write(f"{key}\n")
    
    return cogs


def find_pending_conversions(
    config: Config, 
    tiffs: list[tuple[str, int]], 
    cogs: set[str]
) -> list[tuple[str, int]]:
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
# AWS Batch Infrastructure Setup
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


def ensure_batch_service_role(config: Config) -> str:
    """Ensure Batch service role exists."""
    iam = get_iam_client(config)
    role_name = "AWSBatchServiceRole"
    
    try:
        response = iam.get_role(RoleName=role_name)
        return response["Role"]["Arn"]
    except iam.exceptions.NoSuchEntityException:
        info(f"Creating Batch service role: {role_name}", config)
        
        trust_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "batch.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }
        
        response = iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description="AWS Batch service role"
        )
        
        iam.attach_role_policy(
            RoleName=role_name,
            PolicyArn="arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
        )
        
        time.sleep(10)  # Wait for role propagation
        return response["Role"]["Arn"]


def ensure_ecs_instance_role(config: Config) -> str:
    """Ensure ECS instance role exists for Batch compute environment."""
    iam = get_iam_client(config)
    role_name = "ecsInstanceRole"
    
    try:
        response = iam.get_role(RoleName=role_name)
        return response["Role"]["Arn"]
    except iam.exceptions.NoSuchEntityException:
        info(f"Creating ECS instance role: {role_name}", config)
        
        trust_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "ec2.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }
        
        response = iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description="ECS instance role for Batch"
        )
        
        iam.attach_role_policy(
            RoleName=role_name,
            PolicyArn="arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
        )
        
        # Create instance profile
        try:
            iam.create_instance_profile(InstanceProfileName=role_name)
            iam.add_role_to_instance_profile(
                InstanceProfileName=role_name,
                RoleName=role_name
            )
        except iam.exceptions.EntityAlreadyExistsException:
            pass
        
        time.sleep(10)
        return response["Role"]["Arn"]


def ensure_batch_job_role(config: Config) -> str:
    """Ensure Batch job execution role exists with S3 access."""
    iam = get_iam_client(config)
    role_name = f"{config.batch_job_name}-job-role"
    
    try:
        response = iam.get_role(RoleName=role_name)
        role_arn = response["Role"]["Arn"]
        info(f"Job role exists: {role_arn}", config)
        return role_arn
    except iam.exceptions.NoSuchEntityException:
        info(f"Creating job role: {role_name}", config)
        
        trust_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "ecs-tasks.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }
        
        response = iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description="Batch job role for COG converter"
        )
        role_arn = response["Role"]["Arn"]
        
        # Attach ECS task execution policy
        iam.attach_role_policy(
            RoleName=role_name,
            PolicyArn="arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
        )
        
        # S3 access policy
        s3_policy = {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:ListBucket",
                    "s3:HeadObject"
                ],
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
        
        info(f"Created job role: {role_arn}", config)
        time.sleep(10)
        return role_arn


def ensure_compute_environment(config: Config) -> str:
    """Ensure Batch compute environment exists."""
    batch = get_batch_client(config)
    
    try:
        response = batch.describe_compute_environments(
            computeEnvironments=[config.compute_env_name]
        )
        if response["computeEnvironments"]:
            env = response["computeEnvironments"][0]
            info(f"Compute environment exists: {env['computeEnvironmentArn']}", config)
            return env["computeEnvironmentArn"]
    except Exception:
        pass
    
    info(f"Creating compute environment: {config.compute_env_name}", config)
    
    # Ensure roles exist
    ensure_batch_service_role(config)
    ensure_ecs_instance_role(config)
    
    # Get default VPC and subnets
    ec2 = get_boto_session(config).client("ec2")
    
    vpcs = ec2.describe_vpcs(Filters=[{"Name": "is-default", "Values": ["true"]}])
    if not vpcs["Vpcs"]:
        error("No default VPC found. Please create one or specify VPC settings.", config)
        sys.exit(1)
    vpc_id = vpcs["Vpcs"][0]["VpcId"]
    
    subnets = ec2.describe_subnets(Filters=[{"Name": "vpc-id", "Values": [vpc_id]}])
    subnet_ids = [s["SubnetId"] for s in subnets["Subnets"]]
    
    # Get default security group
    sgs = ec2.describe_security_groups(
        Filters=[
            {"Name": "vpc-id", "Values": [vpc_id]},
            {"Name": "group-name", "Values": ["default"]}
        ]
    )
    if not sgs["SecurityGroups"]:
        error("No default security group found in VPC.", config)
        sys.exit(1)
    security_group_ids = [sgs["SecurityGroups"][0]["GroupId"]]
    
    compute_resources = {
        "type": "SPOT" if config.use_spot else "EC2",
        "allocationStrategy": "SPOT_CAPACITY_OPTIMIZED" if config.use_spot else "BEST_FIT_PROGRESSIVE",
        "minvCpus": 0,
        "maxvCpus": config.max_vcpus,
        "instanceTypes": ["optimal"],
        "subnets": subnet_ids,
        "securityGroupIds": security_group_ids,
        "instanceRole": "ecsInstanceRole",
    }
    
    if config.use_spot:
        compute_resources["spotIamFleetRole"] = f"arn:aws:iam::{get_aws_account_id(config)}:role/aws-ec2-spot-fleet-tagging-role"
    
    response = batch.create_compute_environment(
        computeEnvironmentName=config.compute_env_name,
        type="MANAGED",
        state="ENABLED",
        computeResources=compute_resources,
    )
    
    # Wait for compute environment to be valid
    info("Waiting for compute environment to become valid...", config)
    while True:
        time.sleep(5)
        response = batch.describe_compute_environments(
            computeEnvironments=[config.compute_env_name]
        )
        status = response["computeEnvironments"][0]["status"]
        if status == "VALID":
            break
        elif status == "INVALID":
            error(f"Compute environment creation failed", config)
            sys.exit(1)
        info(f"  Status: {status}...", config)
    
    return response["computeEnvironments"][0]["computeEnvironmentArn"]


def ensure_job_queue(config: Config) -> str:
    """Ensure Batch job queue exists."""
    batch = get_batch_client(config)
    
    try:
        response = batch.describe_job_queues(jobQueues=[config.job_queue_name])
        if response["jobQueues"]:
            queue = response["jobQueues"][0]
            info(f"Job queue exists: {queue['jobQueueArn']}", config)
            return queue["jobQueueArn"]
    except Exception:
        pass
    
    info(f"Creating job queue: {config.job_queue_name}", config)
    
    compute_env_arn = ensure_compute_environment(config)
    
    response = batch.create_job_queue(
        jobQueueName=config.job_queue_name,
        state="ENABLED",
        priority=1,
        computeEnvironmentOrder=[{
            "order": 1,
            "computeEnvironment": compute_env_arn
        }]
    )
    
    # Wait for queue to be valid
    info("Waiting for job queue to become valid...", config)
    while True:
        time.sleep(5)
        response = batch.describe_job_queues(jobQueues=[config.job_queue_name])
        status = response["jobQueues"][0]["status"]
        if status == "VALID":
            break
        elif status == "INVALID":
            error("Job queue creation failed", config)
            sys.exit(1)
    
    return response["jobQueues"][0]["jobQueueArn"]


def ensure_job_definition(config: Config, image_uri: str) -> str:
    """Create or update Batch job definition."""
    batch = get_batch_client(config)
    
    info(f"Creating/updating job definition: {config.job_definition_name}", config)
    
    job_role_arn = ensure_batch_job_role(config)
    
    # Build environment variables for job
    env_vars = [
        {"name": "S3_BUCKET", "value": config.s3_bucket},
        {"name": "COG_PREFIX", "value": config.cog_prefix},
        {"name": "COMPRESSION", "value": config.compression},
        {"name": "OVERWRITE", "value": str(config.overwrite).lower()},
    ]
    
    response = batch.register_job_definition(
        jobDefinitionName=config.job_definition_name,
        type="container",
        containerProperties={
            "image": image_uri,
            "vcpus": config.job_vcpus,
            "memory": config.job_memory,
            "jobRoleArn": job_role_arn,
            "executionRoleArn": job_role_arn,
            "environment": env_vars,
        },
        retryStrategy={"attempts": 2},
        timeout={"attemptDurationSeconds": 7200},  # 2 hours max per job
    )
    
    job_def_arn = response["jobDefinitionArn"]
    info(f"Job definition registered: {job_def_arn}", config)
    return job_def_arn


# =============================================================================
# Docker Build and Push
# =============================================================================

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
        ["docker", "build", "-t", image_tag, str(config.docker_dir)],
        check=True
    )
    
    # Push image
    info(f"Pushing image to ECR: {image_tag}", config)
    subprocess.run(["docker", "push", image_tag], check=True)
    
    return image_tag


# =============================================================================
# Job Submission
# =============================================================================

def submit_batch_jobs(config: Config, pending: list[tuple[str, int]]) -> list[dict]:
    """
    Submit batch jobs for pending conversions.
    
    Splits pending files into chunks and submits a job for each chunk.
    Each job processes FILES_PER_JOB files.
    
    Returns:
        List of submitted job info dicts
    """
    if not pending:
        info("No files pending conversion", config)
        return []
    
    batch = get_batch_client(config)
    s3 = get_s3_client(config)
    
    # Get job definition (latest revision)
    response = batch.describe_job_definitions(
        jobDefinitionName=config.job_definition_name,
        status="ACTIVE"
    )
    if not response["jobDefinitions"]:
        error("No active job definition found. Run 'deploy' first.", config)
        sys.exit(1)
    
    job_def = response["jobDefinitions"][-1]["jobDefinitionArn"]
    
    # Split into chunks
    keys = [k for k, _ in pending]
    chunks = [keys[i:i + config.files_per_job] for i in range(0, len(keys), config.files_per_job)]
    
    info(f"Submitting {len(chunks)} jobs for {len(keys)} files ({config.files_per_job} files/job)", config)
    
    if config.dry_run:
        info("[DRY RUN] Would submit the following jobs:", config)
        for i, chunk in enumerate(chunks[:5]):
            print(f"  Job {i+1}: {len(chunk)} files")
        if len(chunks) > 5:
            print(f"  ... and {len(chunks) - 5} more jobs")
        return []
    
    submitted_jobs = []
    
    for i, chunk in enumerate(chunks):
        job_name = f"{config.batch_job_name}-{datetime.now().strftime('%Y%m%d%H%M%S')}-{i+1}"
        
        # Upload manifest to S3
        manifest_key = f"{config.cog_prefix}manifests/{job_name}.json"
        manifest_data = json.dumps(chunk)
        s3.put_object(
            Bucket=config.s3_bucket,
            Key=manifest_key,
            Body=manifest_data.encode()
        )
        
        # Submit job
        response = batch.submit_job(
            jobName=job_name,
            jobQueue=config.job_queue_name,
            jobDefinition=job_def,
            containerOverrides={
                "environment": [
                    {"name": "MANIFEST_KEY", "value": manifest_key},
                ]
            }
        )
        
        job_info = {
            "jobId": response["jobId"],
            "jobName": job_name,
            "manifestKey": manifest_key,
            "fileCount": len(chunk),
            "submittedAt": datetime.now().isoformat(),
        }
        submitted_jobs.append(job_info)
        
        info(f"Submitted job {i+1}/{len(chunks)}: {job_name} ({len(chunk)} files)", config)
    
    # Save job info
    with open(config.jobs_file, "w") as f:
        json.dump(submitted_jobs, f, indent=2)
    
    info(f"Submitted {len(submitted_jobs)} jobs. Job info saved to: {config.jobs_file}", config)
    
    return submitted_jobs


def get_job_status(config: Config) -> list[dict]:
    """Get status of submitted jobs."""
    batch = get_batch_client(config)
    
    if not config.jobs_file.exists():
        info("No jobs file found", config)
        return []
    
    with open(config.jobs_file) as f:
        jobs = json.load(f)
    
    if not jobs:
        return []
    
    job_ids = [j["jobId"] for j in jobs]
    
    # AWS Batch can only describe 100 jobs at a time
    all_statuses = []
    for i in range(0, len(job_ids), 100):
        chunk = job_ids[i:i+100]
        response = batch.describe_jobs(jobs=chunk)
        all_statuses.extend(response["jobs"])
    
    # Merge status with our job info
    status_map = {j["jobId"]: j for j in all_statuses}
    
    result = []
    for job in jobs:
        status = status_map.get(job["jobId"], {})
        result.append({
            **job,
            "status": status.get("status", "UNKNOWN"),
            "statusReason": status.get("statusReason", ""),
            "startedAt": status.get("startedAt"),
            "stoppedAt": status.get("stoppedAt"),
        })
    
    return result


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
        total_size = sum(size for _, size in pending)
        print(f"\nPending data size: {total_size / (1024**3):.2f} GB")
        
        num_jobs = math.ceil(len(pending) / config.files_per_job)
        print(f"Estimated jobs: {num_jobs} (at {config.files_per_job} files/job)")
        
        print(f"\nPending list saved to: {config.pending_list}")


def cmd_convert(config: Config):
    """Submit batch jobs for pending conversions."""
    tiffs = list_raw_tiffs(config)
    cogs = list_existing_cogs(config)
    pending = find_pending_conversions(config, tiffs, cogs)
    
    if not pending:
        info("No files pending conversion!", config)
        return
    
    submit_batch_jobs(config, pending)


def cmd_jobs(config: Config):
    """Show status of batch jobs."""
    jobs = get_job_status(config)
    
    if not jobs:
        print("No jobs found")
        return
    
    print("\n" + "=" * 80)
    print("Batch Job Status")
    print("=" * 80)
    
    status_counts = {}
    for job in jobs:
        status = job["status"]
        status_counts[status] = status_counts.get(status, 0) + 1
    
    print(f"Total jobs: {len(jobs)}")
    for status, count in sorted(status_counts.items()):
        print(f"  {status}: {count}")
    
    print("-" * 80)
    print(f"{'Job Name':<45} {'Files':<8} {'Status':<12}")
    print("-" * 80)
    
    for job in jobs[:20]:
        print(f"{job['jobName']:<45} {job['fileCount']:<8} {job['status']:<12}")
    
    if len(jobs) > 20:
        print(f"... and {len(jobs) - 20} more jobs")
    
    print("=" * 80)


def cmd_setup(config: Config):
    """Set up AWS Batch infrastructure."""
    info("Setting up AWS Batch infrastructure...", config)
    
    if config.dry_run:
        info("[DRY RUN] Would create:", config)
        print("  - ECR repository")
        print("  - IAM roles (batch service, ECS instance, job execution)")
        print("  - Batch compute environment")
        print("  - Batch job queue")
        return
    
    ensure_ecr_repo(config)
    ensure_job_queue(config)  # This creates compute env and roles too
    
    info("AWS Batch infrastructure setup complete!", config)
    info("Next step: Run 'deploy' to build and push the Docker image", config)


def cmd_deploy(config: Config):
    """Build and deploy Docker image, create job definition."""
    info("Deploying COG converter...", config)
    
    if config.dry_run:
        info("[DRY RUN] Would:", config)
        print("  - Build Docker image")
        print("  - Push to ECR")
        print("  - Create/update job definition")
        return
    
    # Ensure ECR repo exists
    repo_uri = ensure_ecr_repo(config)
    
    # Build and push image
    image_uri = build_and_push_image(config, repo_uri)
    
    # Create job definition
    ensure_job_definition(config, image_uri)
    
    info("Deployment complete!", config)


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="COG Conversion Manager (AWS Batch)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Environment Variables:
  S3_BUCKET           S3 bucket name (required)
  SOURCE_PREFIX       Source prefix for raw TIFFs (default: cartodb_exports/rasters/)
  COG_PREFIX          Destination prefix for COGs (default: cartodb_exports/cogs/)
  AWS_REGION          AWS region (default: us-east-1)
  AWS_PROFILE         AWS credentials profile name
  FILES_PER_JOB       Files to process per batch job (default: 50)
  MAX_VCPUS           Maximum concurrent vCPUs (default: 16)
  USE_SPOT            Use spot instances (default: true)
  FILENAME_FILTER     Regex to filter filenames
  DRY_RUN             Show what would run without executing (true/false)

Examples:
  # Initial setup
  S3_BUCKET=my-bucket python manage_cog_conversion.py setup
  S3_BUCKET=my-bucket python manage_cog_conversion.py deploy
  
  # Check status and convert
  S3_BUCKET=my-bucket python manage_cog_conversion.py status
  S3_BUCKET=my-bucket python manage_cog_conversion.py convert
  
  # Monitor jobs
  S3_BUCKET=my-bucket python manage_cog_conversion.py jobs
        """
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    subparsers.add_parser("list", help="List all raw TIFFs")
    subparsers.add_parser("status", help="Show conversion status")
    subparsers.add_parser("convert", help="Submit batch jobs for pending conversions")
    subparsers.add_parser("jobs", help="Show status of batch jobs")
    subparsers.add_parser("setup", help="Set up AWS Batch infrastructure")
    subparsers.add_parser("deploy", help="Build and push Docker image")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    config = Config()
    config.validate()
    
    commands = {
        "list": cmd_list,
        "status": cmd_status,
        "convert": cmd_convert,
        "jobs": cmd_jobs,
        "setup": cmd_setup,
        "deploy": cmd_deploy,
    }
    
    commands[args.command](config)


if __name__ == "__main__":
    main()
