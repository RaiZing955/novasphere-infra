# State partage, versionne et chiffre, avec verrouillage natif S3 (pas de DynamoDB).
# Un backend n'accepte pas de variables : le bucket est ecrit en clair (ce n'est pas un secret).
# Dev et prod ne different QUE par la cle.
terraform {
  backend "s3" {
    bucket       = "novasphere-tfstate-kay"
    key          = "novasphere/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
