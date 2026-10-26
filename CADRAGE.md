# CADRAGE : fiche de cadrage

> À faire valider par l'intervenant. Les noms sont à compléter par l'équipe.

## 1. Équipe

| Nom | Rôle |
|---|---|
| NOM Prénom | **Référent Git** |
| NOM Prénom | **Référent AWS** |
| NOM Prénom | membre |

Équipe : `<nom de l'équipe>` - Classe : `<classe>`

## 2. Contexte métier (cinq lignes)

NovaSphere est une startup SaaS fictive (le contexte du cours) dont nous reprenons l'infrastructure.
Le service web doit rester disponible aux pics de trafic et ne jamais exposer de secret.
Deux environnements : `dev` (on casse et on teste) et `prod` (seul ce qui a été validé en dev est déployé).
Les changements passent par pull request relue, avec le plan de l'infrastructure sous les yeux.
La page d'accueil indique l'environnement et l'instance qui répond.

## 3. Ce que servent les instances

Une page HTML statique générée au démarrage par nginx (nom de l'environnement, nom de l'instance, état de
lecture du secret) ; `/release` est une réponse fixe de l'ALB.

## 4. Extension choisie : tests de module

`terraform test` sur le module d'équipe `terraform-aws-web-sg`, provider simulé, exécuté dans la CI du module.
**Ce qu'elle exige** : un dossier `tests/` dans le dépôt du module, un workflow dédié ; aucun coût AWS, aucune
NAT Gateway, aucune ressource supplémentaire.

## 5. Ce que l'équipe écarte, et pourquoi

HTTPS (pas de domaine ni de certificat dans le lab), RDS (coût et temps), image Packer et Ansible (le socle
réclame le temps), second service (non noté), NAT Gateway (coût horaire). Une seule extension, comme demandé.

## 6. Compte AWS utilisé pour la démonstration

AWS Academy **Learner Lab**, région `us-east-1`. Credentials de session remis à jour dans les secrets du
dépôt avant la soutenance. Profil d'instance imposé : `LabInstanceProfile`.

## 7. Validation

Validé par l'intervenant : ____________________  Date : ____________
