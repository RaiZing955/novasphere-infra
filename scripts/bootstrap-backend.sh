#!/usr/bin/env bash
# Cree le bucket S3 du state (une seule fois par equipe, AVANT le premier commit de code Terraform).
# Usage : ./scripts/bootstrap-backend.sh <trigramme>
set -euo pipefail

TRI="${1:?Usage: $0 <trigramme>}"
BUCKET="novasphere-tfstate-${TRI}"
REGION="us-east-1"

aws sts get-caller-identity >/dev/null   # echoue si les credentials du lab sont perimes

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Le bucket $BUCKET existe deja."
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Bucket de state pret : s3://$BUCKET (versionne, chiffre, prive)"
