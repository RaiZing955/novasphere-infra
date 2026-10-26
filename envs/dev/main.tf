data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  name     = "novasphere-${var.environment}"
  ssm_path = "/novasphere/${var.environment}"

  # Dev et prod ont chacun leur VPC, avec des plages differentes.
  vpc_cidr = var.environment == "prod" ? "10.1.0.0/16" : "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]
}
