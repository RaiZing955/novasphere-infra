# NovaSphere : infrastructure web multi-environnements sur AWS

Infrastructure as Code du projet fil rouge (module « Terraform et Automatisation du déploiement
d'infrastructures dans le cloud », Master SRC). Deux environnements, `dev` et `prod`, déployés par une
chaîne GitHub Actions, sans aucun secret dans le code.

    Internet --> ALB (80) --> Target group --> ASG (min 2, max 4) --> nginx
                                               instances en 2 zones, Security Group : port 80 depuis l'ALB seulement
    Secret : Parameter Store (SecureString) --> lu par l'instance au démarrage via son profil IAM

Secrets et IAM : [SECURITE.md](SECURITE.md). Architecture : [ARCHITECTURE.md](ARCHITECTURE.md).
Règles d'équipe : [CONTRIBUTING.md](CONTRIBUTING.md).

## Deux dépôts

| Dépôt | Rôle |
|---|---|
| `novasphere-infra` (celui-ci) | environnements `dev` / `prod`, CI, documents |
| `terraform-aws-web-sg` | module de l'équipe (Security Group web fermé), appelé par hash de commit du tag `v1.0.0` |

Le module est **public** : `terraform init` le télécharge depuis GitHub.

## Prérequis

| Outil | Version |
|---|---|
| Terraform | 1.14 ou supérieur |
| AWS CLI | 2.x |
| Git | 2.30 ou supérieur |
| GitHub CLI (`gh`) | pour les scripts de configuration |

Compte AWS : **Learner Lab**, région `us-east-1`. Aucune clé AWS n'est jamais écrite dans un fichier du dépôt.

## Déployer de zéro

### 1. Credentials du lab

Lab démarré (pastille AWS verte), menu **AWS Details, AWS CLI, Show** : exporter les trois variables
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`. Elles changent à **chaque session**.

    aws sts get-caller-identity     # doit afficher un JSON avec Account

### 2. Personnaliser

Le bucket de state s'appelle `novasphere-tfstate-<trigramme>` (ici `kay`) et le module vient du compte
GitHub `RaiZing955`. Ces valeurs sont dans `envs/*/backend.tf` et `envs/*/web.tf`.

### 3. Bucket de state partagé (avant le premier commit de code)

    ./scripts/bootstrap-backend.sh kay      # bucket versionné, chiffré, privé

### 4. Déployer `dev` à la main (première vérification)

    cd envs/dev
    export TF_VAR_owner='kay'
    export TF_VAR_environment='dev'
    export TF_VAR_db_password='un-mot-de-passe-de-test'   # jamais dans un fichier
    terraform init
    terraform plan           # LIRE le plan en entier
    terraform apply

### 5. Vérifier

    ALB=$(terraform output -raw alb_dns_name)
    sleep 120                                       # le health check doit passer au vert
    for i in 1 2 3 4; do curl -s "http://$ALB/"; echo; done    # deux noms d'hôte alternent
    curl -s "http://$ALB/release"                   # réponse fixe de l'ALB
    terraform state pull | grep -c "$TF_VAR_db_password"       # doit afficher 0 : le secret n'est pas dans le state

Même chose pour `prod` (`cd ../prod`, `TF_VAR_environment=prod`, `TF_VAR_instance_type=t3.small`).

### 6. Brancher la CI

    ./scripts/setup-github.sh RaiZing955/novasphere-infra kay

Crée la variable `OWNER`, les environnements `dev` et `prod` (prod : approbation requise), les secrets
`DB_PASSWORD` (un par environnement) et les credentials de session du lab. Ensuite le flux est :

1. branche, modification, **pull request** : `fmt`, `validate`, `checkov`, puis **plan dev et prod en commentaire** ;
2. relecture, **merge sur `main`** : `apply` de dev à partir du fichier de plan ;
3. `prod` attend l'**approbation** (onglet Actions, « Review deployments »), puis s'applique ;
4. chaque nuit (et sur demande : *Run workflow*) le job de **dérive** lance `plan -detailed-exitcode`.

Avant chaque soutenance ou session : `./scripts/update-lab-credentials.sh RaiZing955/novasphere-infra`.

### 7. Détruire (fin de chaque session, sans exception)

    ./scripts/destroy-all.sh kay

Vérifier en console : plus de Load Balancer ni d'instance EC2. Le bucket de state est conservé.

## Dépannage rapide

| Message | Cause | Action |
|---|---|---|
| `ExpiredToken` / `InvalidClientTokenId` | credentials du lab périmés | refaire l'étape 1 (et `update-lab-credentials.sh` pour la CI) |
| `Error acquiring the state lock` | un autre `apply` tourne, ou un verrou orphelin | demander à l'équipe ; `terraform force-unlock <ID>` seulement si personne n'opère |
| `BucketAlreadyExists` | trigramme déjà pris | en choisir un autre |
| `AWSServiceRoleForAutoScaling` refusé au premier `apply` | rôle lié du lab pas encore propagé | attendre 1 minute et relancer `apply` |
| Cibles `unhealthy` | `bootstrap.sh` a échoué | `/var/log/cloud-init-output.log` ; vérifier le paramètre `/novasphere/<env>/db_password` |

## Compte AWS personnel (hors lab)

Les workflows savent utiliser OIDC : si la variable de dépôt `AWS_ROLE_ARN` est définie, ils assument ce rôle
au lieu d'utiliser des clés stockées. La création du rôle OIDC n'est pas incluse (interdite dans le Learner Lab).
