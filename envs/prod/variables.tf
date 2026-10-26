variable "owner" {
  description = "Proprietaire / equipe (tag Owner)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.owner))
    error_message = "owner : 2 a 20 caracteres, minuscules, chiffres et tirets."
  }
}

variable "environment" {
  description = "Nom de l'environnement."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment doit valoir dev ou prod."
  }
}

variable "instance_type" {
  description = "Type d'instance du groupe d'auto-scaling."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "instance_type doit etre t3.micro, t3.small ou t3.medium (limites du Learner Lab)."
  }
}

variable "release_label" {
  description = "Libelle de version expose par l'ALB sur /release (sert a montrer un changement visible en demonstration)."
  type        = string
  default     = "v2"
}

# AUCUNE valeur par defaut. Fournie par TF_VAR_db_password (jamais par un tfvars commite).
# ephemeral = true : Terraform refuse de la memoriser dans le state ou dans le plan.
variable "db_password" {
  description = "Secret applicatif, fourni par TF_VAR_db_password et ecrit dans Parameter Store en ecriture seule."
  type        = string
  ephemeral   = true
  sensitive   = true
}

variable "db_password_version" {
  description = "A incrementer pour declencher une rotation du secret (value_wo_version)."
  type        = number
  default     = 1
}

variable "use_lab_profile" {
  description = "true dans le Learner Lab (profil LabInstanceProfile impose) ; false sur un compte personnel (role au moindre privilege cree par secrets.tf)."
  type        = bool
  default     = true
}
