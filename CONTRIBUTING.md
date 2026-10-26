# CONTRIBUTING : règles d'équipe

1. `main` est protégée en pratique : **une branche par changement**, une pull request, relue par un **autre** membre avant merge.
2. Chaque membre commite **depuis son poste, sous son propre nom** (`git config user.name` et `user.email`).
3. Le plan de la PR se lit **en entier** (commentaire de la CI) avant d'approuver ; on n'applique que ce qui a été relu.
4. `.gitignore` est **non négociable** : jamais de `*.tfstate*`, `*.tfvars`, `*.pem`, `.env`, `.terraform/`.
5. **Aucun secret nulle part** : ni code, ni tfstate, ni `bootstrap.sh`, ni historique Git, ni logs de CI. Le secret passe par `TF_VAR_db_password` (local) ou les secrets d'environnement GitHub (CI).
6. Le state est **distant** (S3, verrou natif `use_lockfile = true`) dès le premier commit. Aucun state local, jamais.
7. `terraform force-unlock` **uniquement** après avoir vérifié, à la voix ou par message, que personne n'a d'opération en cours.
8. Les versions de module se **publient par tag** (`vX.Y.Z`), ne se modifient **jamais** après publication ; la promotion = changer la référence du module en dev, valider, puis en prod.
9. `terraform destroy` (`./scripts/destroy-all.sh`) **avant de quitter** chaque session : un ALB oublié consomme le budget du lab. Pas de NAT Gateway ajoutée « depuis un tutoriel ».
10. Messages de commit à l'impératif, une idée par commit ; ouvrir la PR tôt, relire vite.

Note sur le backend : la doc du backend S3 indique que l'argument `dynamodb_table` est **déprécié** ; nous utilisons `use_lockfile = true` et ne reproduisons pas l'approche DynamoDB.
