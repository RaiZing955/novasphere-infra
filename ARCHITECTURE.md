# ARCHITECTURE

## Schéma

                        Internet
                           |  :80
                  +--------v--------+
                  |  ALB (public)   |  SG alb : 80 depuis 0.0.0.0/0, sortie 80
                  |  /release : 200 |  (réponse fixe, démo rapide)
                  +---+---------+---+
        subnet public a         subnet public b      VPC 10.0.0.0/16 (dev) | 10.1.0.0/16 (prod)
             +-----v----+     +----v-----+          module registre terraform-aws-modules/vpc, 2 zones, sans NAT
             | EC2 nginx|     | EC2 nginx|          ASG min 2 / max 4, Launch Template (IMDSv2, EBS chiffré)
             +-----+----+     +----+-----+          SG web : 80 depuis le SG de l'ALB uniquement, aucun SSH
                   +-------+-------+
                           | ssm:GetParameter (profil d'instance)
                  +--------v-----------------+
                  | Parameter Store          |  /novasphere/<env>/db_password  (SecureString)
                  | écrit par Terraform (wo) |
                  +--------------------------+

    State : S3 novasphere-tfstate-kay, clés novasphere/dev/... et novasphere/prod/... (versionné, chiffré, use_lockfile)
    CI    : GitHub Actions. PR : fmt, validate, checkov, plan commenté. main : apply dev, prod après approbation. Dérive nocturne.

## Contexte métier

NovaSphere est la startup SaaS fictive du cours, dont l'équipe reprend l'infrastructure pour la faire grandir.
Le service web doit rester disponible aux pics de trafic ; la page d'accueil identifie l'environnement et
l'instance qui répond ; `/release` est une réponse fixe de l'ALB (démo rapide).

## Décisions prises (et pourquoi)

| Décision | Raison |
|---|---|
| State S3 versionné + `use_lockfile = true` | travail à plusieurs sans corruption ; verrou natif (la table DynamoDB est dépréciée) ; versionnement = filet de sécurité |
| Un répertoire par environnement (`envs/dev`, `envs/prod`) | la cible est visible dans le chemin ; states et droits séparables ; les workspaces masquent la cible |
| Dev et prod identiques sauf la clé du backend et les valeurs | ce qui est validé en dev est exactement ce qui part en prod |
| Module d'équipe `terraform-aws-web-sg` appelé par hash de commit du tag `v1.0.0` | appelé deux fois (ALB, instances), corrigé à un seul endroit ; le hash ne peut pas être déplacé (corrige CKV_TF_1) |
| VPC via le module public du registre | brique standard : on ne réécrit pas une trentaine de ressources |
| Pas de NAT Gateway, instances en subnets publics | coût (environ 0,05 $/h) ; l'exposition est maîtrisée par les Security Groups |
| Security Group des instances : source = SG de l'ALB | personne d'autre que l'ALB ne parle aux instances ; aucun SSH |
| ASG + `health_check_type = "ELB"` | une instance qui ne répond plus sur `/` est remplacée sans intervention |
| Amorçage par `bootstrap.sh` (8 lignes) | court et reproductible ; il lit le secret, n'en embarque aucun |
| Secret : Parameter Store, `value_wo` + variable `ephemeral` | le secret n'entre ni dans le code, ni dans le state, ni dans le plan, ni dans `user_data` |
| IMDSv2 exigé | bloque le vol de credentials d'instance par SSRF |
| Plan sauvegardé (`-out=tfplan`) puis `apply tfplan` | on applique exactement ce qui a été relu |
| Credentials de session en secrets du dépôt (lab) | le lab interdit la création de rôle IAM et de fournisseur OIDC ; les workflows basculent sur OIDC si `AWS_ROLE_ARN` est défini |

## Alternatives écartées

| Écarté | Pourquoi |
|---|---|
| Workspaces Terraform | mêmes credentials et même bucket pour dev et prod, erreur de cible trop facile |
| State local | non partagé, contient des données sensibles, pas de verrou |
| NAT Gateway + subnets privés | coût horaire ; hors socle ; aurait imposé une destruction systématique |
| Secret dans une variable avec `default` ou dans `user_data` | fuite dans le code, le state, `DescribeInstanceAttribute` |
| Secrets Manager | 0,40 $/secret/mois, rotation inutile ici ; Parameter Store suffit |
| Stocker une clé AWS permanente dans GitHub | permanente, non restreinte ; seule contrainte du lab : clés de session temporaires, documentées dans SECURITE.md |
| Image préconstruite (Packer), Ansible, RDS, HTTPS, second service | hors périmètre : une seule extension est notée, voir ci-dessous |

## Extension choisie : tests de module

`terraform test` sur `terraform-aws-web-sg`, avec **provider simulé** (`mock_provider "aws"`) : aucun credential,
aucun coût, exécutable partout. Les 7 tests vérifient le nommage du Security Group et que les validations refusent bien
SSH, `0.0.0.0/0` hors ports web, un CIDR invalide, un VPC mal formé et l'absence de source. Ils tournent dans la CI du module
(`.github/workflows/test.yml`) à chaque pull request. Aucune NAT Gateway n'est nécessaire.

## Limites connues

- Pas de HTTPS : pas de domaine ni de certificat ACM dans le lab (le listener 443 est l'évolution naturelle).
- Instances en subnets publics (sans NAT) : acceptable parce que seul l'ALB peut les joindre sur le port 80.
- Les credentials de session du lab expirent : la dérive nocturne échoue tant que le lab est arrêté.
