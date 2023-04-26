resource "aws_s3_bucket" "build_artifacts_bucket" {
  bucket = var.bucket_name
}

data "aws_iam_policy_document" "resilience_atlas_access_for_deployment_document" {
  statement {
    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.build_artifacts_bucket.arn}/*",
      aws_s3_bucket.build_artifacts_bucket.arn
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    effect = "Deny"
  }

  statement {
    actions = [
      "s3:GetObject*",
      "s3:PutObject*",
      "s3:GetBucket*",
      "s3:List*"
    ]
    resources = [
      "${aws_s3_bucket.build_artifacts_bucket.arn}/*",
      aws_s3_bucket.build_artifacts_bucket.arn
    ]
    principals {
      type = "AWS"
      identifiers = [
        var.cloud_formation_role_arn,
        var.pipeline_role_arn
      ]
    }
    effect = "Allow"
  }
}

resource "aws_s3_bucket_policy" "ResilienceAtlasAccessForDeployment" {
  bucket = aws_s3_bucket.build_artifacts_bucket.id
  policy = data.aws_iam_policy_document.resilience_atlas_access_for_deployment_document.json
}
