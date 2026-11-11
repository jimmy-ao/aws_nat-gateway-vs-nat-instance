# providers

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Region      = var.region
      Environment = var.environment
    }
  }
}
