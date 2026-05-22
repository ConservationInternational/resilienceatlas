#!/usr/bin/env bash
#
# Invalidate the Martin CDN CloudFront cache.
#
# Run this after reimporting boundary data or updating Martin tile sources.
#
# Usage:
#   ./invalidate-martin-cache.sh --staging   [--profile resilienceatlas]
#   ./invalidate-martin-cache.sh --production [--profile resilienceatlas]
#   ./invalidate-martin-cache.sh --staging --paths "/boundary_tiles/*"
#
# Without --paths, invalidates all cached content (/*).
# By default, waits for the invalidation to complete before exiting.
# Use --no-wait to return immediately after submitting.

set -euo pipefail

REGION="us-east-1"
PROFILE_ARG=""
ENV=""
PATHS="/*"
WAIT=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staging)     ENV="staging"; shift ;;
    --production)  ENV="production"; shift ;;
    --profile)     PROFILE_ARG="--profile $2"; shift 2 ;;
    --paths)       PATHS="$2"; shift 2 ;;
    --no-wait)     WAIT=false; shift ;;
    -h|--help)
      echo "Usage: $0 --staging|--production [--profile <aws-profile>] [--paths <pattern>] [--no-wait]"
      echo ""
      echo "Examples:"
      echo "  $0 --staging                              # Invalidate all cached tiles (waits for completion)"
      echo "  $0 --staging --no-wait                    # Submit invalidation and return immediately"
      echo "  $0 --staging --paths '/boundary_tiles/*'   # Invalidate only boundary tiles"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "Error: specify --staging or --production"
  exit 1
fi

if [[ "$ENV" == "staging" ]]; then
  STACK_NAME="martin-cdn-staging"
else
  STACK_NAME="martin-cdn-production"
fi

echo "Looking up CloudFront distribution for $STACK_NAME..."
DIST_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" \
  --output text \
  $PROFILE_ARG)

if [[ -z "$DIST_ID" || "$DIST_ID" == "None" ]]; then
  echo "Error: Could not find CloudFront distribution for stack $STACK_NAME"
  exit 1
fi

echo "Creating invalidation for distribution $DIST_ID..."
echo "  Paths: $PATHS"

INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "$PATHS" \
  --query "Invalidation.Id" \
  --output text \
  $PROFILE_ARG)

echo "Invalidation created: $INVALIDATION_ID"

if [[ "$WAIT" == "true" ]]; then
  echo ""
  echo "Waiting for invalidation to complete across all edge locations..."
  aws cloudfront wait invalidation-completed \
    --distribution-id "$DIST_ID" \
    --id "$INVALIDATION_ID" \
    $PROFILE_ARG
  echo "Done. All edge locations have been cleared."
  echo ""
  echo "Note: Tiles will be re-cached on first access — seeing 'Hit from cloudfront'"
  echo "after this is expected and means CloudFront fetched a fresh copy from Martin."
else
  echo ""
  echo "Check status with:"
  echo "  aws cloudfront get-invalidation --distribution-id $DIST_ID --id $INVALIDATION_ID $PROFILE_ARG"
fi
