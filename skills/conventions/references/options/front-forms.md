# Option `front-forms` — formulaires du frontend Angular

Clé dans `.claude/stack.json` : `"conventions": { "front-forms": "<valeur>" }`. Sans frontend, l'option est ignorée.

## Valeur : reactive
- Formulaires réactifs **typés** : `inject(NonNullableFormBuilder)` ou `FormBuilder.nonNullable`, un `FormGroup` par formulaire.
- Validateurs alignés sur les contraintes des DTO backend (`required`, `maxLength`, `pattern`…), messages d'erreur en
  français affichés sous le champ, après `touched` ou soumission.
- Bouton de soumission désactivé pendant l'envoi (signal `submitting`), jamais pour masquer une erreur de validation.
- Les erreurs de validation renvoyées par le backend (`ProblemDetail` avec erreurs par champ) sont reportées sur les champs.

## Valeur : signal
- **Signal Forms** (`@angular/forms/signals`), uniquement si la version d'Angular installée les fournit **en stable** ;
  sinon, arrête-toi et signale-le (l'option ne s'applique pas à une API expérimentale).
- Mêmes règles que `reactive` : validateurs alignés sur les DTO, messages en français, erreurs serveur reportées sur les champs.
