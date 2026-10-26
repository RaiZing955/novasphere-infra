# value_wo : Terraform envoie la valeur a AWS mais ne la garde NI dans le state NI dans le plan.
# value_wo_version est obligatoire avec value_wo : comme Terraform ne memorise pas la valeur, il ne peut
# pas detecter qu'elle a change ; on incremente la version pour declencher une nouvelle ecriture (rotation).
resource "aws_ssm_parameter" "db_password" {
  #checkov:skip=CKV_AWS_337:cle KMS geree par AWS (alias/aws/ssm) : une CMK n'apporte rien de plus dans le lab
  name             = "${local.ssm_path}/db_password"
  type             = "SecureString"
  value_wo         = var.db_password
  value_wo_version = var.db_password_version
}

# Dans le Learner Lab : creation de role IAM interdite, on utilise le profil impose LabInstanceProfile.
# Hors lab (use_lab_profile = false) : role limite a ssm:GetParameter sur le chemin de CET environnement.
data "aws_iam_policy_document" "ec2_assume" {
  count = var.use_lab_profile ? 0 : 1

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "read_secrets" {
  count = var.use_lab_profile ? 0 : 1

  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_path}/*"]
  }
}

resource "aws_iam_role" "web" {
  count = var.use_lab_profile ? 0 : 1

  name               = "${local.name}-web"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume[0].json
}

resource "aws_iam_role_policy" "read_secrets" {
  count = var.use_lab_profile ? 0 : 1

  name   = "read-secrets"
  role   = aws_iam_role.web[0].id
  policy = data.aws_iam_policy_document.read_secrets[0].json
}

resource "aws_iam_instance_profile" "web" {
  count = var.use_lab_profile ? 0 : 1

  name = "${local.name}-web"
  role = aws_iam_role.web[0].name
}

locals {
  instance_profile_name = var.use_lab_profile ? "LabInstanceProfile" : one(aws_iam_instance_profile.web[*].name)
}
