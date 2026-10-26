#!/usr/bin/env bash
# Fin de session de travail : detruit prod puis dev. A lancer AVANT de quitter, sans exception.
# Usage : ./scripts/destroy-all.sh <trigramme>
set -euo pipefail

OWNER="${1:?Usage: $0 <trigramme>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export TF_VAR_db_password="destroy-placeholder"
export TF_VAR_owner="$OWNER"

for ENV in prod dev; do
  echo "=== destroy $ENV ==="
  cd "$ROOT/envs/$ENV"
  TF_VAR_environment="$ENV" terraform init -input=false >/dev/null
  TF_VAR_environment="$ENV" TF_VAR_instance_type="$([ "$ENV" = prod ] && echo t3.small || echo t3.micro)" \
    terraform destroy -auto-approve -input=false
done

echo "Verifiez en console : plus aucun Load Balancer ni instance EC2."
