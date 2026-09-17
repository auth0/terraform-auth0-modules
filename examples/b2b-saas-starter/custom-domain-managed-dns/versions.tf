terraform {
  required_version = ">= 1.3.0"

  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.51"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
