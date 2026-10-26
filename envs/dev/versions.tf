terraform {
  # 1.11 minimum pour les arguments en ecriture seule (value_wo), 1.14 = version de reference du cours.
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # seule region autorisee (avec us-west-2) dans le Learner Lab

  default_tags {
    tags = {
      Project     = "novasphere"
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}
