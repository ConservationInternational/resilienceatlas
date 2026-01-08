#!/bin/bash
# ============================================================================
# CodeDeploy Agent Installation Script
# ============================================================================
# This script installs and configures the AWS CodeDeploy agent on an EC2 
# instance. Run this on each EC2 instance that will receive deployments.
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Detect the AWS region using IMDSv2 (more secure and reliable)
log_info "Detecting AWS region..."

# First, get IMDSv2 token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || echo "")

if [ -n "$TOKEN" ]; then
    # Use IMDSv2
    REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "")
else
    # Fallback to IMDSv1
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "")
fi

# Validate region format
if [ -z "$REGION" ] || [[ ! "$REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
    log_warning "Could not detect region from metadata service"
    log_warning "This can happen if IMDSv2 is required but not configured, or if running outside EC2"
    read -p "Enter AWS region (e.g., us-east-1): " REGION
    
    # Validate user input
    if [[ ! "$REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
        log_error "Invalid region format. Expected format: us-east-1, eu-west-2, etc."
        exit 1
    fi
fi

log_info "Using AWS region: $REGION"

# Update system packages
log_info "Updating system packages..."
apt-get update -y

# Install required dependencies
log_info "Installing dependencies..."
apt-get install -y ruby-full wget

# Download the CodeDeploy agent installer
log_info "Downloading CodeDeploy agent..."
cd /tmp

CODEDEPLOY_URL="https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"
log_info "Download URL: $CODEDEPLOY_URL"

if ! wget "$CODEDEPLOY_URL" -O install; then
    log_error "Failed to download CodeDeploy agent installer"
    log_error "Please verify the region '$REGION' is correct and has CodeDeploy available"
    exit 1
fi

# Make the installer executable
chmod +x install

# Install the CodeDeploy agent
log_info "Installing CodeDeploy agent..."
./install auto

# Start the CodeDeploy agent
log_info "Starting CodeDeploy agent..."
systemctl start codedeploy-agent
systemctl enable codedeploy-agent

# Verify the installation
log_info "Verifying installation..."
sleep 5

if systemctl is-active --quiet codedeploy-agent; then
    log_success "CodeDeploy agent is running"
else
    log_error "CodeDeploy agent failed to start"
    log_info "Checking logs..."
    journalctl -u codedeploy-agent --no-pager -n 20
    exit 1
fi

# Show agent status
log_info "CodeDeploy agent status:"
systemctl status codedeploy-agent --no-pager

# Clean up
rm -f /tmp/install

log_success "CodeDeploy agent installation complete!"

# Additional configuration
log_info "Additional configuration..."

# Create log directory
mkdir -p /var/log/aws/codedeploy-agent

# Configure log rotation
cat > /etc/logrotate.d/codedeploy-agent << 'EOF'
/var/log/aws/codedeploy-agent/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

log_success "Log rotation configured"

# Summary
echo ""
echo "============================================================"
log_success "CodeDeploy Agent Setup Complete!"
echo "============================================================"
echo ""
log_info "The CodeDeploy agent is now running and will automatically"
log_info "receive deployments from AWS CodeDeploy."
echo ""
log_info "Next steps:"
echo "1. Tag this EC2 instance with the appropriate tags:"
echo "   - Environment = staging OR production"
echo "   - Project = ResilienceAtlas"
echo ""
echo "2. Ensure the instance has the correct IAM role attached:"
echo "   - ResilienceAtlasEC2Profile (created by setup_ec2_instance_role.py)"
echo ""
echo "3. Verify the deployment group in CodeDeploy includes this instance"
echo ""
log_info "To check agent status: sudo systemctl status codedeploy-agent"
log_info "To view agent logs: sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log"
