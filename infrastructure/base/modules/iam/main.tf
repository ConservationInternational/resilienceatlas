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
    resources = [aws_iam_role.pipeline_role.arn]
    effect    = "Allow"
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_iam_policy" "workload_boundary" {
  name = "resilienceatlas-workload-boundary"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/resilienceatlas-*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [var.build_artifacts_bucket_arn, "${var.build_artifacts_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:${data.aws_partition.current.partition}:lambda:*:${data.aws_caller_identity.current.account_id}:function:resilienceatlas-*"
      }
    ]
  })
}

# Cloud Formation execution role
resource "aws_iam_role" "cloud_formation_role" {
  name               = "resilience-atlas-CloudFormationExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.cloud_formation_role_assume_role_policy_document.json
  tags = {
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
    resources = ["arn:${data.aws_partition.current.partition}:cloudformation:*:${data.aws_caller_identity.current.account_id}:stack/resilienceatlas-*/*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "lambda:*"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:lambda:*:${data.aws_caller_identity.current.account_id}:function:resilienceatlas-*"]
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
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:AttachRolePolicy"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/resilienceatlas-workload/*"]
    effect    = "Allow"
  }
  statement {
    actions   = ["iam:CreateRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/resilienceatlas-workload/*"]
    effect    = "Allow"
    condition {
      test     = "ArnEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.workload_boundary.arn]
    }
  }
  statement {
    actions   = ["iam:PassRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/resilienceatlas-workload/*"]
    effect    = "Allow"
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
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
    resources = [var.ecr_repository_arn]
    effect    = "Allow"
  }
}

# Pipeline execution role
resource "aws_iam_role" "pipeline_role" {
  name               = "resilience-atlas-PipelineExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.pipeline_role_assume_role_policy_document.json
  tags = {
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
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["cloudformation.amazonaws.com"]
    }
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
    resources = [var.ecr_repository_arn]
    effect    = "Allow"
  }
}
