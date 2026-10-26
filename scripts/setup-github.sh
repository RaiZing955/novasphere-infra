#!/usr/bin/env bash
# Configure le depot GitHub : variables, environnements dev/prod, secrets.
# Usage : ./scripts/setup-github.sh <utilisateur/depot> <trigramme>
set -euo pipefail

REPO="${1:?Usage: $0 <utilisateur/depot> <trigramme>}"
OWNER="${2:?Usage: $0 <utilisateur/depot> <trigramme>}"

gh variable set OWNER --repo "$REPO" --body "$OWNER"

gh api -X PUT "repos/$REPO/environments/dev" >/dev/null
USER_ID="$(gh api user -q .id)"
gh api -X PUT "repos/$REPO/environments/prod" --input - >/dev/null <<JSON
{"reviewers":[{"type":"User","id":$USER_ID}]}
JSON
echo "Environnements dev et prod crees (prod : approbation requise)."

for ENV in dev prod; do
  read -r -s -p "Mot de passe applicatif pour $ENV (invisible) : " PW; echo
  printf '%s' "$PW" | gh secret set DB_PASSWORD --env "$ENV" --repo "$REPO"
done

"$(dirname "$0")/update-lab-credentials.sh" "$REPO"
