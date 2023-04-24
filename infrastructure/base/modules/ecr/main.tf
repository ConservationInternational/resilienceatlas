resource "aws_ecr_repository" "pipeline_resources" {
  name                 = "resilience-atlas-pipeline-resources"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
