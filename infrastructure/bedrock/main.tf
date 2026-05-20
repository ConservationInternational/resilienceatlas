terraform {
  backend "s3" {
    bucket = "resilienceatlas-terraform-state-211441814460"
    region = "us-east-1"
    # key is passed via -backend-config="key=bedrock/staging.tfstate" at init time
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

variable "environment" {
  description = "deployment environment (staging or production)"
}

variable "embeddings_bucket_name" {
  description = "S3 bucket name for embeddings index and knowledge base docs"
}

variable "rails_api_url" {
  description = "Base URL of the Rails API"
}

# ─── S3 Bucket for embeddings + KB docs ──────────────────────────────────────

resource "aws_s3_bucket" "embeddings" {
  bucket = var.embeddings_bucket_name
}

resource "aws_s3_bucket_versioning" "embeddings" {
  bucket = aws_s3_bucket.embeddings.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "embeddings" {
  bucket = aws_s3_bucket.embeddings.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "embeddings" {
  bucket                  = aws_s3_bucket.embeddings.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload knowledge base docs to S3
resource "aws_s3_object" "kb_docs" {
  for_each = fileset("${path.module}/../../cloud_functions/ai_agent/knowledge_base", "**/*.json")
  bucket   = aws_s3_bucket.embeddings.id
  key      = "ai_agent/knowledge_base/${each.value}"
  source   = "${path.module}/../../cloud_functions/ai_agent/knowledge_base/${each.value}"
  etag     = filemd5("${path.module}/../../cloud_functions/ai_agent/knowledge_base/${each.value}")
}

# ─── IAM Roles ───────────────────────────────────────────────────────────────

# Role for Bedrock Agent itself
resource "aws_iam_role" "bedrock_agent" {
  name = "resilienceatlas-bedrock-agent-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_agent_policy" {
  name = "bedrock-agent-policy"
  role = aws_iam_role.bedrock_agent.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

# Placeholder locals — the actual Lambda ARNs come from SAM deploy outputs
locals {
  stack_name               = "resilienceatlas-ai-agent-${var.environment}"
  action_groups_lambda_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.stack_name}-action-groups"
}

resource "aws_iam_role_policy" "bedrock_agent_lambda" {
  name = "bedrock-agent-lambda-invoke"
  role = aws_iam_role.bedrock_agent.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = "arn:aws:lambda:${var.aws_region}:*:function:${local.stack_name}-action-groups"
    }]
  })
}

# ─── Grant EC2 app role permission to invoke the Bedrock agent ───────────────

data "aws_iam_role" "ec2_role" {
  name = "ResilienceAtlasEC2Role"
}

resource "aws_iam_role_policy" "ec2_bedrock_invoke" {
  name = "bedrock-invoke-agent-${var.environment}"
  role = data.aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeAgent"]
      Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:agent-alias/${aws_bedrockagent_agent.main.id}/${aws_bedrockagent_agent_alias.live.agent_alias_id}"
    }]
  })
}

# ─── Bedrock Agent ───────────────────────────────────────────────────────────

resource "aws_bedrockagent_agent" "main" {
  agent_name              = "resilienceatlas-layer-manager-${var.environment}"
  description             = "AI agent for creating and managing Resilience Atlas map layers"
  foundation_model        = "anthropic.claude-sonnet-4-5-20250929-v1:0"
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  instruction             = file("${path.module}/../../cloud_functions/ai_agent/bedrock_agent/agent_instructions.txt")

  idle_session_ttl_in_seconds = 1800
}

resource "aws_bedrockagent_agent_action_group" "layer_tools" {
  agent_id          = aws_bedrockagent_agent.main.id
  agent_version     = "DRAFT"
  action_group_name = "LayerManagementTools"
  description       = "Tools for creating layers, searching context, and importing vector data"

  action_group_executor {
    lambda = local.action_groups_lambda_arn
  }

  api_schema {
    payload = file("${path.module}/../../cloud_functions/ai_agent/bedrock_agent/action_group_schema.yaml")
  }
}

resource "aws_bedrockagent_agent_alias" "live" {
  agent_id         = aws_bedrockagent_agent.main.id
  agent_alias_name = "live-${var.environment}"
  description      = "Production-ready alias for ${var.environment}"
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "bedrock_agent_id" {
  description = "Bedrock Agent ID — set as BEDROCK_AGENT_ID in GitHub secrets"
  value       = aws_bedrockagent_agent.main.id
}

output "bedrock_agent_alias_id" {
  description = "Bedrock Agent Alias ID — set as BEDROCK_AGENT_ALIAS_ID in GitHub secrets"
  value       = aws_bedrockagent_agent_alias.live.agent_alias_id
}

output "embeddings_bucket_name" {
  description = "S3 bucket name for embeddings — set as AI_EMBEDDINGS_BUCKET in GitHub secrets"
  value       = aws_s3_bucket.embeddings.id
}
