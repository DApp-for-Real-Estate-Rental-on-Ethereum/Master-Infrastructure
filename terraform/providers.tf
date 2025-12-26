terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      Project     = "Derent-dApp"
      Environment = "Production"
      ManagedBy   = "Terraform"
    }
  }
}
