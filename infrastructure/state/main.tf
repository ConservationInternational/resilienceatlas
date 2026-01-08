resource "aws_s3_bucket" "terraform-state-bucket" {
  bucket = "resilienceatlas-terraform-state"
}

resource "aws_s3_bucket_ownership_controls" "terraform-state-bucket-ownership-controls" {
  bucket = aws_s3_bucket.terraform-state-bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "terraform-state-bucket-versioning" {
  bucket = aws_s3_bucket.terraform-state-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
