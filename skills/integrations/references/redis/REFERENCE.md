# Intégration — Redis
> Statut : testée

## Résumé
Cache clé-valeur en mémoire, partagé entre les instances de l'application, accédé avec Spring Data Redis (client Lettuce).
Rôle : `sortant-cache`. Le cache accélère des lectures ; il n'est **jamais** la source de vérité. Validée sur Bibliothèque.

## Cas d'usage
- Lectures fréquentes et coûteuses dont le résultat change peu (catalogue, référentiels, résultats calculés).
- Données éphémères partagées entre instances : limitation de débit, verrous courts, sessions.
- **Ne pas** l'utiliser pour une donnée qui n'existe nulle part ailleurs (Redis peut perdre des données),
  ni comme file de messages fiable (préférer RabbitMQ ou Kafka). Un cache local (Caffeine) suffit si l'application
  n'a qu'une instance.

## Dépendances
- `spring-boot-starter-data-redis` (Lettuce inclus ; validé avec Spring Boot 4.1.1 : Spring Data Redis 4.1.1, Lettuce 7.5.x)
- Optionnel, seulement pour `@Cacheable` : `spring-boot-starter-cache`
- Tests : `spring-boot-testcontainers`, `org.testcontainers:testcontainers-junit-jupiter`, et `org.awaitility:awaitility`
  (scope `test`, déclaré explicitement, version gérée par le BOM) pour attendre une expiration ou une reconnexion

## Connexion et configuration
```yaml
spring:
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD}     # secret : aucune valeur par défaut (socle)
      ssl:
        enabled: ${REDIS_SSL:false}
      timeout: 2s                     # délai maximal d'une commande
      connect-timeout: 2s
      repositories:
        enabled: false                # Redis utilisé comme cache uniquement : pas de repositories Spring Data Redis
app:
  cache:
    ttl:
      default: 10m                    # TTL obligatoire ; un TTL nul ou négatif doit faire échouer le démarrage
```
- **Poste de développement** (Redis sans mot de passe) : `spring.data.redis.password: ""` dans `application-local.yml`.
  Sous Windows, une variable d'environnement vide est supprimée : ne pas compter sur `REDIS_PASSWORD=`.
- **Tests** : `REDIS_PASSWORD=` dans `src/test/resources/application.properties` ; `@ServiceConnection` fournit hôte et port.
- **Échec immédiat quand la connexion est perdue** : `ClientOptions.disconnectedBehavior(REJECT_COMMANDS)` via un bean
  `LettuceClientOptionsBuilderCustomizer` (méthode `customize(ClientOptions.Builder)`), dans `config`. Ne pas utiliser
  l'autre customizer (configuration complète du client), qui écraserait les options de Spring Boot dont le `connect-timeout`.
  La reconnexion automatique est conservée ; sans cette option, chaque commande attend le `timeout` pendant une panne.
- **Sérialisation** : JSON écrit par un `JsonMapper` (Jackson 3) dédié et **strict** (propriétés inconnues refusées,
  champs obligatoires), stocké en `String` via le `StringRedisTemplate` fourni par Spring Boot. **Ne pas** utiliser le
  sérialiseur JSON générique de Spring Data Redis : il écrit des noms de classes Java dans la valeur (typage polymorphe).
  Jamais la sérialisation Java native.

## Rôle dans l'architecture
- `sortant-cache` : un adapter de cache qui implémente un port de sortie (hexagonal) ou un composant `cache` appelé
  par le service (couches). Deux façons de faire :
  - **décorateur** (validé) : l'adapter de cache implémente les mêmes ports que l'adapter de persistance (lecture
    **et** écriture concernées), est déclaré `@Primary`, et reçoit l'adapter de persistance par un nom de bean explicite
    (`@Component("bookPersistenceAdapter")` + `@Qualifier`). Les ports non concernés restent sur la persistance ;
  - **`@Cacheable` / `@CacheEvict`** sur les méthodes de l'adapter de persistance (rôle `sortant-persistance`),
    jamais sur le domaine ni sur un use case.
- La configuration (customizer Lettuce, TTL, `CacheManager` éventuel) va dans un package `config`.
- Un codec dédié (DTO de cache en `record` ↔ objet du domaine) reconstruit les objets par le **même chemin que le mapper
  de persistance** (méthode de reconstitution), jamais par la fabrique de création (qui génère un nouvel id).

## Conventions
- Clés : `<application>:<module>:<objet>[:<identifiant>]:v<n>` (ex. `library:catalog:available-books:v1`).
  Changer le suffixe de version quand le format de la valeur change, au lieu de vider le cache.
- **TTL obligatoire** sur chaque clé, posé avec l'écriture en une seule commande atomique (`SET … PX`).
- Une liste paramétrée par une limite (1 à N) : **une seule clé** contenant les N premiers éléments, déjà triés
  dans l'ordre du domaine ; le décorateur renvoie le préfixe demandé. Une suppression suffit à invalider.
- **Jamais `KEYS`** (ni `SCAN` pour invalider) : supprimer des clés connues avec `DEL`.
- Liste vide en cache : `[]` (distinct d'une clé absente).
- Invalidation **après la validation de la transaction** (`TransactionSynchronization.afterCommit`), immédiate s'il n'y a
  pas de transaction active ; aucune invalidation en cas de rollback. Une erreur Redis à ce moment est journalisée,
  jamais propagée (l'écriture en base a réussi).
- **Le cache ne sert qu'à la lecture** : aucun cas d'écriture ne charge un objet depuis le cache (version périmée).
- Valeurs : DTO de cache sérialisables (`record`), jamais d'entité JPA ni d'objet du domaine avec comportement.

## Résilience
- **Redis indisponible ne fait jamais échouer une requête** : la lecture a trois issues —
  valeur trouvée ; clé absente ou valeur illisible (lecture en base **puis** écriture du cache) ;
  Redis injoignable (lecture en base, WARN, **aucune tentative d'écriture**, pour ne pas attendre deux fois).
- **Valeur illisible** = JSON invalide, champ manquant **ou valeur incohérente avec les règles du domaine**
  (bornes, invariants) : la méthode de reconstitution du domaine ne revalide généralement rien, c'est donc au codec
  de contrôler les mêmes bornes que la création. Une valeur illisible est remplacée dès qu'une lecture en base réussit.
- Seules les opérations de cache sont dans le `try` ; une erreur de base de données remonte normalement.
- Pas de cohérence forte : accepter qu'une donnée ait jusqu'à un TTL de retard, et le dire dans la spec.
  Une modification faite **hors de l'application** (SQL à la main, autre service) ne vide pas le cache.
- Risque connu : la lecture du cache a lieu dans la transaction (lecture seule) du cas d'utilisation ; pendant une panne,
  `REJECT_COMMANDS` limite l'attente au premier échec.

## Sécurité
- Mot de passe (ou ACL utilisateur Redis 6+) et TLS hors poste de développement.
- Les WARN contiennent la clé, le type d'exception et un **motif fixe** ; jamais la valeur, ni `e.getMessage()`
  (Jackson recopie un extrait de la valeur dans ses messages), ni stack trace.
- Jamais de donnée personnelle sensible ni de token en clair dans une valeur de cache.
- Ne pas exposer le port Redis sur le réseau public.

## Observabilité
- Health check Actuator `redis` (classes de santé de Spring Boot 4 : `org.springframework.boot.health.*`).
  Par défaut, une panne du cache rend `/actuator/health` **DOWN** : si un orchestrateur s'appuie sur ce statut,
  sortir `redis` du groupe de disponibilité (`management.endpoint.health.group.readiness.include`), puisque
  l'application fonctionne sans cache.
- Pendant une panne, Lettuce (`io.lettuce.core.protocol.ConnectionWatchdog`) journalise chaque tentative de
  reconnexion en WARN avec une stack trace : c'est le comportement normal de la bibliothèque, pas une erreur du code.
- Métriques de cache si `spring-boot-starter-cache` et Micrometer sont présents.

## Développement local
- **Windows** : pas de Redis natif ; conteneur
  `docker run -d --name redis --restart unless-stopped -p 6379:6379 redis:7-alpine`.
- **macOS** : `brew install redis` puis `brew services start redis`, ou le même conteneur.
- **Linux** : paquet `redis-server`, ou le même conteneur.
- Lire une clé : `docker exec redis redis-cli GET <clé>` ; durée restante : `TTL <clé>` ; vider : `DEL <clé>`
  (utile après une modification de la base faite à la main).

## Tests
```java
@TestConfiguration(proxyBeanMethods = false)
public class RedisTestcontainersConfiguration {
    @Bean
    @ServiceConnection(name = "redis")
    GenericContainer<?> redisContainer() {
        return new GenericContainer<>(DockerImageName.parse("redis:7-alpine")).withExposedPorts(6379);
    }
}
```
- **Configuration de test séparée** de celle de PostgreSQL : les slices JPA n'importent que PostgreSQL.
  Si les deux conteneurs sont dans le contexte, qualifier l'injection (`@Qualifier("redisContainer")`), car un
  `PostgreSQLContainer` est aussi un `GenericContainer`.
- Un test qui insère des données en SQL direct doit vider Redis avant et après (aucune invalidation n'a lieu).
- Tests attendus : seconde lecture sans appel à la base ; TTL > 0 ; `[]` ; valeur illisible ou incohérente remplacée ;
  aucune commande `KEYS` (vérifiable avec `INFO commandstats`) ; invalidation après commit et pas après rollback ;
  Redis injoignable → un seul WARN, aucune écriture ; Redis coupé **après** connexion → repli bien plus rapide que le timeout.
- Assertions de logs sur des **constantes** partagées avec le code, pas sur des fragments de texte ; seuils de durée larges
  (ex. repli < 1 s pour un timeout de 3 s) pour rester stables sous Docker Desktop. Jamais `Thread.sleep` : Awaitility.

## Grille de revue
- Aucune classe Redis hors du rôle `sortant-cache` et de `config` ; domaine et use cases sans annotation de cache.
- Chaque clé a un TTL posé atomiquement ; nommage `<application>:<module>:<objet>:v<n>` ; jamais `KEYS`.
- Invalidation après commit, jamais propagée en erreur ; aucune lecture d'écriture depuis le cache.
- Repli sur la base testé (Redis injoignable et valeur illisible) ; pas d'écriture quand Redis est injoignable.
- Sérialisation JSON stricte sans nom de classe ; codec qui contrôle les bornes du domaine.
- `password` sans valeur par défaut ; `REJECT_COMMANDS` configuré sans écraser les options de Spring Boot.
- WARN sans valeur, sans `e.getMessage()`, sans stack trace.
