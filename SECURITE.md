# SECURITE

## 1. Où vivent les secrets

| Secret | Où il vit | Comment il arrive à l'application | Où il ne doit **jamais** apparaître |
|---|---|---|---|
| Mot de passe applicatif (`db_password`) | Parameter Store `/novasphere/<env>/db_password` (SecureString, chiffré KMS) | l'instance le lit au démarrage avec son profil IAM (`aws ssm get-parameter --with-decryption`) et l'écrit dans `/etc/novasphere/app.conf` (mode 0640) | code, `terraform.tfstate`, plan, `user_data`/`bootstrap.sh`, historique Git, logs CI |
| Source côté Terraform | variable `TF_VAR_db_password` (shell local) ou secret **d'environnement** GitHub `DB_PASSWORD` (un par env) | variable `ephemeral = true` → argument `value_wo` (écriture seule) | tfvars commité, `default` |
| Credentials AWS de la CI (lab) | secrets du dépôt `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | `aws-actions/configure-aws-credentials` | code, logs (masqués) |
| Credentials AWS de la CI (compte perso) | **aucun** : rôle IAM assumé par OIDC | jeton signé GitHub, valable 1 h | |

**Pourquoi `value_wo_version` est obligatoire avec `value_wo`** : Terraform ne mémorise pas la valeur
écrite (c'est le but), donc il ne peut pas détecter qu'elle a changé. La version est la seule chose qu'il
compare : on l'incrémente pour déclencher une nouvelle écriture (rotation).

La page d'accueil prouve que le secret a été lu sans l'afficher : elle indique seulement sa **longueur**.

## 2. Preuves à montrer (commandes)

```bash
git grep -n "<valeur-du-secret>" $(git rev-list --all)        # historique : aucune ligne
terraform state pull | grep -c '<valeur-du-secret>'            # 0
aws ec2 describe-instance-attribute --instance-id <id> --attribute userData \
  --query UserData.Value --output text | base64 -d              # aucun secret, seulement le NOM du paramètre
```

## 3. Politique IAM de l'instance

### Idéal (ce que l'instance devrait avoir)

Implémenté dans `secrets.tf` pour `use_lab_profile = false` :

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["ssm:GetParameter"],
    "Resource": "arn:aws:ssm:us-east-1:<compte>:parameter/novasphere/<env>/*"
  }]
}
```

Conséquence : une instance `dev` ne peut pas lire `/novasphere/prod/…` (`AccessDeniedException`) ;
aucune autre action, aucun `Resource = "*"`.

### Dans le Learner Lab

Le lab **interdit la création de rôle IAM** : les instances utilisent le profil imposé `LabInstanceProfile`
(rôle `LabRole`), bien plus large que la politique idéale. Le moindre privilège n'est donc **pas démontrable
par un accès refusé dans le lab** ; il l'est sur un compte personnel avec `use_lab_profile = false`. C'est une
limite de l'environnement, pas un choix d'architecture.

### Authentification de la CI : deux modèles

| | Learner Lab | Compte personnel |
|---|---|---|
| Mécanisme | clés de session stockées dans les secrets du dépôt | rôle IAM + fournisseur OIDC GitHub |
| Durée de vie | la session du lab (quelques heures), à remettre à jour à chaque session | 1 h par exécution, délivrée à la volée |
| Secret stocké | **oui** (3 valeurs, temporaires) | **non** |
| Risque si fuite | accès jusqu'à expiration de la session | pas de secret à voler |

## 4. Réseau

| Règle | Où | Justification |
|---|---|---|
| ingress 80 depuis `0.0.0.0/0` | SG ALB | seule porte publique, volontaire |
| ingress 80 depuis **SG de l'ALB** | SG instances | personne d'autre que l'ALB ne joint les instances |
| **aucun** port 22 | partout | le module refuse 22/3389 ; l'amorçage se fait au démarrage, pas par SSH |
| egress 80 | SG ALB | l'ALB ne parle qu'aux instances |
| egress 80/443 | SG instances | `dnf` (installation de nginx) et appel à Parameter Store ; pas de règle « tout » |
| IMDSv2 exigé (`http_tokens = "required"`) | Launch Template | bloque le vol de credentials d'instance par SSRF |
| EBS chiffré | Launch Template | donnée au repos |
| `drop_invalid_header_fields` | ALB | durcissement HTTP |

## 5. Scan de sécurité

Outil : **checkov**, lancé à chaque pull request par la CI et à la main :

    checkov -d envs/dev  --framework terraform --compact
    checkov -d envs/prod --framework terraform --compact

### Décisions déjà prises dans le code (`#checkov:skip` avec justification)

| Règle | Ressource | Traitement | Justification |
|---|---|---|---|
| CKV_AWS_2, CKV_AWS_103 | `aws_lb_listener.http` | documenté | pas de HTTPS : pas de domaine ni de certificat dans le lab |
| CKV_AWS_150 | `aws_lb.web` | documenté | pas de protection à la suppression : tout est détruit en fin de session |
| CKV_AWS_91 | `aws_lb.web` | documenté | logs d'accès ALB hors périmètre (bucket et politique dédiés) |
| CKV2_AWS_28 | `aws_lb.web` | documenté | pas de WAF : coût, hors cahier des charges |
| CKV_AWS_337 | `aws_ssm_parameter.db_password` | documenté | clé KMS gérée par AWS (`alias/aws/ssm`) |

### Résultats de l'exécution

Premier scan : 20 règles passées, 5 en échec. Après correction : 22 passées, 3 en échec.

| Règle | Ressource | Corrigé / Documenté | Détail |
|---|---|---|---|
| CKV_TF_1 | `module.sg_alb` | **Corrigé** | module d'équipe référencé par hash de commit (`?ref=8cf2dc32...`) au lieu d'un tag déplaçable |
| CKV_TF_1 | `module.sg_web` | **Corrigé** | idem |
| CKV_TF_1 | `module.vpc` | Documenté | module du registre Terraform : la source registre n'accepte pas de hash ; version bornée par `~> 6.0` et plan figé par `.terraform.lock.hcl` |
| CKV2_AWS_20 | `aws_lb.web` | Documenté | pas de redirection HTTP vers HTTPS : aucun certificat ni domaine dans le Learner Lab |
| CKV_AWS_378 | `aws_lb_target_group.web` | Documenté | trafic ALB vers instances en HTTP, à l'intérieur du VPC ; le TLS demande un certificat, indisponible dans le lab |

Risque accepté : sans HTTPS, le trafic entre un client et l'ALB n'est pas chiffré. Ici la page ne contient aucun secret
(elle n'affiche que la longueur du mot de passe). Sur un compte personnel : certificat ACM, listener 443 et redirection 80 vers 443.

## 6. Hygiène Git

`.gitignore` exclut state, `*.tfvars`, clés, `.env`, `.terraform/` et plans. Seul `terraform.tfvars.example` (sans secret)
est versionné. `.terraform.lock.hcl` est versionné (reproductibilité des providers).
