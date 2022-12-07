terraform {
  required_version = ">=0.12.0"
  required_providers {
    aws = ">=3.0.0"
  }
}

provider "aws" {
  profile = var.profile
  region  = "us-east-1"
}