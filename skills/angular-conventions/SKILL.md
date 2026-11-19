---
name: angular-conventions
description: Conventions Angular du projet (socle frontend) — structure par feature, composants, services HTTP, authentification JWT, gestion des erreurs, tests, garde-fous. Les options front-ui et front-forms viennent du skill conventions. À charger avant d'écrire, de planifier ou de relire du code frontend.
---

# Conventions Angular (socle frontend)

> `<frontend>` est le dossier du frontend, annoncé au début de la session (champ `frontend` de `.claude/factory.json`).
> S'il est annoncé « aucun », il n'y a pas de frontend : n'écris pas de code Angular et signale-le ; il se crée par
> `/add-frontend`. `<kit>` est le dossier du kit.

## Procédure
1. Lis ce fichier **en entier** : c'est le socle, il s'applique toujours.
2. Options : skill `conventions`, options `front-ui` (bibliothèque d'interface) et `front-forms` (formulaires) ;
   dans `<kit>/skills/conventions/references/options/front-<option>.md`, lis **uniquement** la section de la valeur retenue.
3. Imite une feature existante du projet avant d'en créer une nouvelle.
4. Version d'Angular : celle de `<frontend>/package.json`. N'utilise pas une API absente de cette version ;
   en cas de doute sur une API propre à une version, consulte la documentation officielle (angular.dev).

## Structure
```
<frontend>/
  proxy.conf.json        /api → backend local (http://localhost:8080) ; aucune URL d'API en dur dans le code
  src/app/
    app.config.ts        providers : router, HttpClient + intercepteurs, bibliothèque d'interface
    app.routes.ts        routes de premier niveau, features chargées en lazy (loadChildren / loadComponent)
    core/                transverse, chargé une fois : auth/ (service, intercepteur, guards), http/ (intercepteur
                         d'erreurs, modèle ProblemDetail), layout/ (en-tête, navigation)
    shared/              composants, pipes, directives réutilisables, sans dépendance métier ni accès HTTP
    features/<feature>/
      <feature>.routes.ts
      data/              <feature>.model.ts (interfaces alignées sur les DTO), <feature>.service.ts (seul accès HTTP)
      pages/             composants routés (liste, détail, formulaire) : orchestrent, appellent le service
      ui/                composants de présentation : input()/output() uniquement, aucun service métier
```
Nommage : `kebab-case` pour les fichiers (`book-list.page.ts` ou `book-list.component.ts`, selon la version du CLI :
garder la convention qu'il génère), `PascalCase` pour les classes, une classe par fichier.

## Règles de dépendance (vérifiées par le hook après chaque écriture, voir `references/rules.conf`)
- `features/<a>` n'importe jamais `features/<b>` : ce qui est partagé va dans `shared/` (UI) ou `core/` (transverse).
- `shared/` n'importe ni `features/` ni `core/` ; `core/` n'importe pas `features/`.
- `HttpClient` uniquement dans les services (`data/` d'une feature, `core/`) : jamais dans `pages/`, `ui/` ou `shared/`.
- `ui/` n'injecte aucun service de `data/` : il reçoit ses données par `input()` et émet par `output()`.

## Composants
- Composants standalone (comportement par défaut des versions récentes : ne pas écrire `standalone: true` si le CLI
  ne le génère pas), `changeDetection: ChangeDetectionStrategy.OnPush`.
- État local en `signal()` / `computed()` ; `input()`, `output()`, `model()` plutôt que les décorateurs.
- Contrôle de flux des templates : `@if`, `@for` (avec `track`), `@switch` ; pas de `*ngIf` / `*ngFor` dans le code neuf.
- `inject()` plutôt que l'injection par constructeur. Fichiers `.ts` / `.html` / `.scss` séparés au-delà de 15 lignes de template.
- Aucune logique métier dans les templates ; aucune règle métier dupliquée du backend (le backend reste la référence).

## Services HTTP
```ts
@Injectable({ providedIn: 'root' })
export class BookService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = '/api/v1/books';          // relatif : le proxy (dev) ou le reverse proxy (prod) route vers l'API

  list(page = 0, size = 20) {
    return this.http.get<Page<Book>>(this.baseUrl, { params: { page, size } });
  }
  register(body: RegisterBookRequest) {
    return this.http.post<Book>(this.baseUrl, body);
  }
}
```
- Modèles TypeScript alignés sur les DTO du contrat d'API (mêmes noms de champs), jamais sur les entités.
- Pas de `subscribe` imbriqués ; dans un composant, `toSignal()` ou `takeUntilDestroyed()` — aucun abonnement non libéré.

## Authentification (JWT émis par le backend)
- `core/auth/auth.service.ts` : `login(credentials)` appelle l'endpoint de connexion du backend ; le jeton est gardé
  dans un `signal` et dans `sessionStorage` (survit au rechargement, disparaît à la fermeture de l'onglet) —
  **jamais `localStorage`**, jamais dans une URL, jamais dans un log. `logout()` efface tout.
- Rôles et expiration lus dans la charge utile du JWT **pour l'affichage seulement** (décodage base64url, sans
  vérification de signature : la sécurité réelle est côté backend). Jeton expiré = déconnexion.
- `core/auth/auth.interceptor.ts` (intercepteur fonctionnel, `withInterceptors`) : ajoute `Authorization: Bearer …`
  **uniquement** aux requêtes relatives vers `/api` ; sur une réponse 401, déconnecte et redirige vers la connexion
  (en conservant l'URL demandée en paramètre `returnUrl`, validée comme chemin interne).
- `core/auth/auth.guard.ts` (`CanActivateFn`) : route protégée → connexion si non authentifié ; `roleGuard('LIBRARIAN')`
  pour les routes réservées. Les guards masquent l'interface, ils ne protègent rien : chaque endpoint reste protégé côté backend.
- Écran de connexion : message d'erreur **générique** (« Identifiant ou mot de passe incorrect »), jamais
  « utilisateur inconnu » ; champ mot de passe masqué ; aucun identifiant pré-rempli dans le code.

## Erreurs
- `core/http/error.interceptor.ts` : traduit les erreurs HTTP en notifications (selon `front-ui`) ; lit le `ProblemDetail`
  (`title`, `detail`, erreurs par champ) ; message générique pour un 5xx ou un échec réseau, sans détail technique.
- 400 avec erreurs par champ : reportées sur le formulaire (option `front-forms`), pas seulement en notification.
- 403 : « Vous n'avez pas les droits nécessaires » ; 401 : géré par l'intercepteur d'authentification.

## Tests
- Lanceur : celui du projet (`ng test` : Vitest pour les projets récents, Karma pour les plus anciens) ; exécution
  non interactive `npx ng test --watch=false` depuis `<frontend>`.
- Services : `provideHttpClient()` + `provideHttpClientTesting()`, `HttpTestingController` (URL, méthode, corps).
- Intercepteurs et guards : testés isolément (jeton ajouté seulement vers `/api`, 401 → déconnexion, redirection).
- Composants clés (pages) : rendu, interactions, affichage des erreurs ; composants `ui/` par leurs entrées et sorties.

## Vérifications avant de rendre la main
Depuis `<frontend>` : `npx ng build` (compile les templates), `npm run lint` si le script existe, `npx ng test --watch=false`.
Le hook vérifie aussi les types (TypeScript) après chaque écriture d'un `.ts`.

## Interdits
`any` (préférer `unknown` + rétrécissement), URL d'API absolue dans le code, jeton dans `localStorage`, `HttpClient` hors
d'un service, import d'une feature par une autre, abonnement non libéré, `console.log` laissé dans le code.
