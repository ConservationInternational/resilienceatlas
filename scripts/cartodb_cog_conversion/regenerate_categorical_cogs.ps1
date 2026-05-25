# Regenerate Categorical COGs - PowerShell Script
# 
# This is a convenience wrapper for Windows users.
# 
# Usage:
#   .\regenerate_categorical_cogs.ps1 -DryRun      # Preview only
#   .\regenerate_categorical_cogs.ps1              # Actually run
#   .\regenerate_categorical_cogs.ps1 -Limit 1     # Test with one file

param(
    [switch]$DryRun,
    [string]$Filter,
    [int]$Limit,
    [string]$S3Bucket = $env:S3_BUCKET,
    [string]$AWSProfile = $env:AWS_PROFILE
)

# Color output helpers
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }

Write-Info "=" * 80
Write-Info "Categorical COG Regeneration (PowerShell)"
Write-Info "=" * 80

# Check S3_BUCKET
if (-not $S3Bucket) {
    Write-Error "ERROR: S3_BUCKET not set"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  `$env:S3_BUCKET='resilienceatlas'"
    Write-Host "  `$env:AWS_PROFILE='resilienceatlas'  # if needed"
    Write-Host "  .\regenerate_categorical_cogs.ps1"
    Write-Host ""
    Write-Host "Or pass as parameter:"
    Write-Host "  .\regenerate_categorical_cogs.ps1 -S3Bucket resilienceatlas -AWSProfile resilienceatlas"
    exit 1
}

# Check Python
try {
    $pythonVersion = python --version 2>&1
    Write-Info "Python: $pythonVersion"
} catch {
    Write-Error "ERROR: Python not found in PATH"
    Write-Error "Install Python 3.8+ from https://www.python.org/downloads/"
    exit 1
}

# Check dependencies
Write-Info "Checking dependencies..."
$missingDeps = @()

python -c "import psycopg2" 2>$null
if ($LASTEXITCODE -ne 0) {
    $missingDeps += "psycopg2-binary"
}

python -c "import boto3" 2>$null
if ($LASTEXITCODE -ne 0) {
    $missingDeps += "boto3"
}

if ($missingDeps.Count -gt 0) {
    Write-Warning "Missing dependencies: $($missingDeps -join ', ')"
    $install = Read-Host "Install now? [Y/n]"
    if ($install -eq '' -or $install -eq 'Y' -or $install -eq 'y') {
        pip install $missingDeps
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install dependencies"
            exit 1
        }
    } else {
        Write-Error "Cannot proceed without dependencies"
        exit 1
    }
}

# Set environment variables
$env:S3_BUCKET = $S3Bucket
if ($AWSProfile) {
    $env:AWS_PROFILE = $AWSProfile
}

# Build Python command arguments
$args = @()
if ($DryRun) {
    $args += "--dry-run"
}
if ($Filter) {
    $args += "--filter=$Filter"
}
if ($Limit -gt 0) {
    $args += "--limit=$Limit"
}

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir "regenerate_categorical_cogs.py"

if (-not (Test-Path $pythonScript)) {
    Write-Error "ERROR: regenerate_categorical_cogs.py not found at $pythonScript"
    exit 1
}

# Run Python script
Write-Info ""
Write-Info "Running: python regenerate_categorical_cogs.py $($args -join ' ')"
Write-Info ""

python $pythonScript @args
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    if (-not $DryRun) {
        Write-Success ""
        Write-Success "=" * 80
        Write-Success "SUCCESS!"
        Write-Success "=" * 80
        Write-Success "Categorical COGs have been regenerated with NEAREST resampling."
        Write-Success ""
        Write-Success "Next steps:"
        Write-Success "  1. Clear browser cache"
        Write-Success "  2. Reload staging.resilienceatlas.org"
        Write-Success "  3. Test land cover layers at zoom levels 3-8"
        Write-Success "  4. Verify clean boundaries (no noise)"
    }
} else {
    Write-Error ""
    Write-Error "Failed with exit code $exitCode"
}

exit $exitCode
