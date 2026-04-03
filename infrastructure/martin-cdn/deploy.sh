#!/usr/bin/env bash
#
# Deploy (or update) the Martin CDN CloudFront distribution.
#
# Usage:
#   ./deploy.sh --staging   [--profile resilienceatlas]
#   ./deploy.sh --production [--profile resilienceatlas]
#
# Prerequisites:
#   - AWS CLI v2 installed
#   - ALB already routing Martin hosts on HTTP listener (run setup_alb.py first)
#   - GitHub secrets: ROUTE_53_ZONE_ID
#
# The ACM certificate uses DNS validation via Route53.  First deploy may take
# 5-30 minutes while the certificate is validated.

set -euo pipefail

ALB_DNS="ALB-P-ResAtl-1-607414703.us-east-1.elb.amazonaws.com"
REGION="us-east-1"
TEMPLATE="$(cd "$(dirname "$0")" && pwd)/template.yaml"
PROFILE_ARG=""

usage() {
  echo "Usage: $0 --staging|--production [--profile <aws-profile>] [--zone-id <zone-id>]"
  exit 1
}

ENV=""
ZONE_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staging)     ENV="staging"; shift ;;
    --production)  ENV="production"; shift ;;
    --profile)     PROFILE_ARG="--profile $2"; shift 2 ;;
    --zone-id)     ZONE_ID="$2"; shift 2 ;;
    *)             usage ;;
  esac
done

[[ -z "$ENV" ]] && usage

if [[ "$ENV" == "staging" ]]; then
  STACK_NAME="martin-cdn-staging"
  FQDN="tiles.staging.resilienceatlas.org"
  CACHE_TTL=3600   # 1 hour for staging (faster iteration)
else
  STACK_NAME="martin-cdn-production"
  FQDN="tiles.resilienceatlas.org"
  CACHE_TTL=86400  # 24 hours for production
fi

# Zone ID can come from CLI arg, env var, or we look it up
if [[ -z "$ZONE_ID" ]]; then
  ZONE_ID="${ROUTE_53_ZONE_ID:-}"
fi
if [[ -z "$ZONE_ID" ]]; then
  echo "Looking up Route53 zone for resilienceatlas.org..."
  ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name "resilienceatlas.org" \
    --query "HostedZones[0].Id" \
    --output text $PROFILE_ARG | sed 's|/hostedzone/||')
  echo "Found zone: $ZONE_ID"
fi

echo "=== Deploying Martin CDN ==="
echo "  Environment: $ENV"
echo "  Stack:       $STACK_NAME"
echo "  FQDN:        $FQDN"
echo "  ALB:         $ALB_DNS"
echo "  Cache TTL:   ${CACHE_TTL}s"
echo "  Zone ID:     $ZONE_ID"
echo ""

aws cloudformation deploy \
  --template-file "$TEMPLATE" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    FQDN="$FQDN" \
    ZoneId="$ZONE_ID" \
    ALBDomainName="$ALB_DNS" \
    CacheTTL="$CACHE_TTL" \
  --region "$REGION" \
  --no-fail-on-empty-changeset \
  $PROFILE_ARG

echo ""
echo "=== Stack outputs ==="
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs" \
  --output table \
  $PROFILE_ARG

echo ""
echo "Done. Verify with:"
echo "  curl -I https://$FQDN/health"
