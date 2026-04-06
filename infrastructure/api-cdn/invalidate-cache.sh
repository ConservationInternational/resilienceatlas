#!/usr/bin/env bash
#
# Invalidate the API CDN CloudFront cache.
#
# Usage:
#   ./invalidate-cache.sh --staging    [--profile resilienceatlas]
#   ./invalidate-cache.sh --production [--profile resilienceatlas]
#   ./invalidate-cache.sh --staging    --path "/api/layers*" [--profile resilienceatlas]
#
# By default invalidates all paths (/*). Use --path to invalidate specific endpoints.

set -euo pipefail

REGION="us-east-1"
PROFILE_ARG=""
INVALIDATION_PATH="/*"

usage() {
  echo "Usage: $0 --staging|--production [--profile <aws-profile>] [--path <path-pattern>]"
  exit 1
}

ENV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staging)     ENV="staging"; shift ;;
    --production)  ENV="production"; shift ;;
    --profile)     PROFILE_ARG="--profile $2"; shift 2 ;;
    --path)        INVALIDATION_PATH="$2"; shift 2 ;;
    *)             usage ;;
  esac
done

[[ -z "$ENV" ]] && usage

if [[ "$ENV" == "staging" ]]; then
  STACK_NAME="api-cdn-staging"
else
  STACK_NAME="api-cdn-production"
fi

echo "Looking up CloudFront distribution for $STACK_NAME..."
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" \
  --output text \
  $PROFILE_ARG)

if [[ -z "$DISTRIBUTION_ID" || "$DISTRIBUTION_ID" == "None" ]]; then
  echo "ERROR: Could not find CloudFront distribution for stack $STACK_NAME"
  exit 1
fi

echo "Invalidating cache for distribution $DISTRIBUTION_ID..."
echo "  Path pattern: $INVALIDATION_PATH"

INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "Quantity=1,Items=$INVALIDATION_PATH" \
  --query "Invalidation.Id" \
  --output text \
  $PROFILE_ARG)

echo "Invalidation created: $INVALIDATION_ID"
echo "Waiting for invalidation to complete..."

aws cloudfront wait invalidation-completed \
  --distribution-id "$DISTRIBUTION_ID" \
  --id "$INVALIDATION_ID" \
  $PROFILE_ARG

echo "Done. Cache invalidated for $INVALIDATION_PATH"
