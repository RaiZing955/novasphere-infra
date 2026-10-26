#!/usr/bin/env bash
# Pousse les credentials de la session Learner Lab courante dans les secrets du depot.
# A relancer a chaque nouvelle session et AVANT la soutenance.
# Usage : ./scripts/update-lab-credentials.sh <utilisateur/depot>
set -euo pipefail

REPO="${1:?Usage: $0 <utilisateur/depot>}"

aws sts get-caller-identity >/dev/null

aws configure get aws_access_key_id     | gh secret set AWS_ACCESS_KEY_ID     --repo "$REPO"
aws configure get aws_secret_access_key | gh secret set AWS_SECRET_ACCESS_KEY --repo "$REPO"
aws configure get aws_session_token     | gh secret set AWS_SESSION_TOKEN     --repo "$REPO"

echo "Credentials de session mis a jour dans $REPO."
