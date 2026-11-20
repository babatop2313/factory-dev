# Option `auth-token` — transport du JWT entre le navigateur et le backend

Clé dans `.claude/stack.json` : `"conventions": { "auth-token": "<valeur>" }`.
Option **backend et frontend** : elle décide comment le backend remet le jeton à l'application Angular et comment il le
relit. Les clients qui ne sont pas des navigateurs (tests, serveur MCP, scripts) utilisent toujours l'en-tête
`Authorization: Bearer`, quelle que soit la valeur.

## Valeur : cookie-httponly
Le jeton n'est **jamais lisible par JavaScript** : une faille XSS ne peut pas le voler.

**Backend**
- Connexion réussie : le jeton part dans un cookie `Set-Cookie: <nom>=<jwt>; HttpOnly; Secure; SameSite=Strict;
  Path=/api; Max-Age=<durée du jeton>` (construit avec `ResponseCookie`). Le corps de la réponse ne contient **pas** le
  jeton : seulement ce que l'interface affiche (identifiant, e-mail, rôles, date d'expiration).
- `Secure` toujours : les navigateurs l'acceptent sur `http://localhost`. Nom du cookie : `__Host-` est impossible avec
  `Path=/api` ; utiliser un nom simple (ex. `ACCESS_TOKEN`), configurable.
- Lecture : un `BearerTokenResolver` qui prend l'en-tête `Authorization` s'il est présent, sinon le cookie.
- **CSRF obligatoire** pour les requêtes authentifiées par cookie : `CookieCsrfTokenRepository.withHttpOnlyFalse()`
  (cookie `XSRF-TOKEN`, en-tête `X-XSRF-TOKEN`) et `CsrfTokenRequestAttributeHandler` ; les requêtes qui portent un
  en-tête `Authorization: Bearer` en sont dispensées (elles ne sont pas exposées au CSRF). L'endpoint de connexion
  initialise le jeton CSRF. `SameSite=Strict` complète, ne remplace pas.
- `POST <api>/auth/logout` : renvoie le cookie vidé (`Max-Age=0`, mêmes attributs) ; 204.
- `GET <api>/auth/me` : identité de l'utilisateur courant (e-mail, rôles, expiration) ou 401 — c'est ainsi que le
  frontend sait s'il est connecté.
- **Pièges vérifiés en conditions réelles** (chacun couvert par un test) :
  - le résolveur de jeton **ignore le cookie** sur la connexion et la déconnexion (un cookie expiré bloquerait la
    connexion) ; si un en-tête `Authorization` est présent, le cookie n'est **jamais** lu ;
  - **contournement CSRF** : cookie valide + en-tête `Authorization` qui n'est pas `Bearer` (`Basic …`, vide) → 401,
    jamais une requête acceptée sans jeton CSRF ; tester POST, PUT et DELETE par cookie sans jeton → 403 ;
  - le cookie `XSRF-TOKEN` ne doit pas être **écrasé** par les réponses de connexion et de déconnexion ; il est `Secure`
    et `SameSite=Strict`, et reste lisible par JavaScript (`HttpOnly` absent : c'est voulu) ;
  - les 401 et 403 de Spring Security renvoient un `ProblemDetail` (comme le reste de l'API), et **tout 401** porte
    `WWW-Authenticate: Bearer` — y compris l'échec de connexion ;
  - `/error` accessible sans authentification ; un endpoint public l'est pour **sa méthode seulement**
    (`permitAll` sur `POST /dev/token`, pas sur toutes les méthodes) ;
  - un compte désactivé reste utilisable jusqu'à l'expiration de son jeton si `/me` ne relit pas la base : à écrire
    comme limite connue (ou relire la base) ;
  - le serveur de test (MockMvc) ne recopie pas toujours l'attribut `SameSite` dans l'en-tête : vérifier l'objet cookie.
- Pas de CORS : le frontend est servi sur la même origine (proxy en développement, reverse proxy en production).

**Frontend**
- Le service d'authentification ne manipule **aucun jeton** : `login()` appelle l'endpoint de connexion et garde dans un
  `signal` l'utilisateur renvoyé ; au démarrage (`provideAppInitializer`), `GET /api/.../auth/me` restaure la session
  (401 = non connecté) ; `logout()` appelle l'endpoint de déconnexion puis vide le signal.
- Aucun intercepteur n'ajoute d'en-tête `Authorization`. Le CSRF est géré par `HttpClient`
  (`withXsrfConfiguration({ cookieName: 'XSRF-TOKEN', headerName: 'X-XSRF-TOKEN' })`), qui n'envoie l'en-tête que
  pour les URL relatives.
- Intercepteur d'authentification : sur un 401 (hors `auth/me` et connexion), vide le signal et redirige vers la
  connexion avec `returnUrl` (chemin interne validé).
- Rien dans `localStorage` ni `sessionStorage` concernant l'authentification.

## Valeur : session-storage
Plus simple, mais le jeton est lisible par JavaScript (exposé en cas de faille XSS).

**Backend** : la connexion renvoie le jeton dans le corps (`accessToken`, `expiresAt`) ; lecture par l'en-tête
`Authorization: Bearer` uniquement ; pas de CSRF à gérer (aucun cookie d'authentification).

**Frontend** : jeton gardé dans un `signal` et dans `sessionStorage` (survit au rechargement, disparaît à la fermeture
de l'onglet) — jamais `localStorage`, jamais dans une URL ni un log ; rôles et expiration lus dans la charge utile pour
l'affichage seulement ; jeton expiré au chargement = déconnecté ; intercepteur qui ajoute `Authorization: Bearer`
**uniquement** aux requêtes relatives vers `/api`, et qui déconnecte sur un 401.
