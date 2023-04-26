terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.64.0"
    }
    github = {
      source  = "integrations/github"
      version = "5.23.0"
    }
  }
  required_version = "~> 1.4.5"
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.allowed_account_id]
}

# https://github.com/integrations/terraform-provider-github/issues/667#issuecomment-1182340862
provider "github" {
  #  owner = "Vizzuality"
}
