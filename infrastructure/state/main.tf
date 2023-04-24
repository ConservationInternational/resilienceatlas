resource "aws_s3_bucket" "terraform-state-bucket" {
  bucket = "resilience-atlas-terraform-state"
}

resource "aws_s3_bucket_acl" "terraform-state-bucket-acl" {
  bucket = aws_s3_bucket.terraform-state-bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "terraform-state-bucket-versioning" {
  bucket = aws_s3_bucket.terraform-state-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
