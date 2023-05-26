# This user's access key & secret access key will be needed in GH Secrets
resource "aws_iam_user" "pipeline_user" {
  name = "resilience-atlas-PipelineUser"
}

resource "aws_iam_access_key" "pipeline_user_access_key" {
  user = aws_iam_user.pipeline_user.name
}

resource "aws_iam_user_policy" "pipeline_user_policy" {
  name   = "ResilienceAtlasAssumePipelineUserPolicy"
  user   = aws_iam_user.pipeline_user.name
  policy = data.aws_iam_policy_document.pipeline_user_policy_document.json
}

data "aws_iam_policy_document" "pipeline_user_policy_document" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Role"
      values   = ["pipeline-execution-role"]
    }
    effect = "Allow"
  }
}

# Cloud Formation execution role
resource "aws_iam_role" "cloud_formation_role" {
  name               = "resilience-atlas-CloudFormationExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.cloud_formation_role_assume_role_policy_document.json
  tags               = {
    Role = "cloud-formation-execution-role"
  }
}

data "aws_iam_policy_document" "cloud_formation_role_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudformation.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "cloud_formation_policy" {
  name   = "ResilienceAtlasCloudFormationExecutionRolePolicy"
  role   = aws_iam_role.cloud_formation_role.name
  policy = data.aws_iam_policy_document.cloud_formation_role_policy_document.json
}

data "aws_iam_policy_document" "cloud_formation_role_policy_document" {
  statement {
    actions = [
      "cloudformation:*"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "lambda:*"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "apigateway:*"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "s3:DeleteObject",
      "s3:GetObject*",
      "s3:PutObject*",
      "s3:GetBucket*",
      "s3:List*"
    ]
    resources = [
      "${var.build_artifacts_bucket_arn}/*",
      var.build_artifacts_bucket_arn
    ]
    effect = "Allow"
  }

  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["acm:*"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["route53:*"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchDeleteImage",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = [var.pipeline_resources_arn]
    effect    = "Allow"
  }
}

# Pipeline execution role
resource "aws_iam_role" "pipeline_role" {
  name               = "resilience-atlas-PipelineExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.pipeline_role_assume_role_policy_document.json
  tags               = {
    Role = "pipeline-execution-role"
  }
}

data "aws_iam_policy_document" "pipeline_role_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.pipeline_user.arn]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role_policy" "pipeline_role_policy" {
  name   = "ResilienceAtlasPipelineExecutionRolePolicy"
  role   = aws_iam_role.pipeline_role.name
  policy = data.aws_iam_policy_document.pipeline_role_policy_document.json
}

data "aws_iam_policy_document" "pipeline_role_policy_document" {
  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.cloud_formation_role.arn]
    effect    = "Allow"
  }

  statement {
    actions = [
      "cloudformation:CreateChangeSet",
      "cloudformation:CreateStack",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStacks",
      "cloudformation:GetTemplate",
      "cloudformation:GetTemplateSummary",
      "cloudformation:DescribeStackResource"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "s3:DeleteObject",
      "s3:GetObject*",
      "s3:PutObject*",
      "s3:GetBucket*",
      "s3:List*"
    ]
    resources = [
      "${var.build_artifacts_bucket_arn}/*",
      var.build_artifacts_bucket_arn
    ]
    effect = "Allow"
  }

  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchDeleteImage",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = [var.pipeline_resources_arn]
    effect    = "Allow"
  }
}
