-- Rôle PostgreSQL en LECTURE SEULE pour le serveur MCP (première ligne de défense).
-- À exécuter par un administrateur (ex. postgres).
--
-- AVANT DE COMMENCER
-- 1. Connectez-vous à la BASE DU PROJET, pas à la base « postgres » :
--      psql    : psql -U postgres -d <base>
--      pgAdmin : clic droit sur la base <base> → Query Tool
--    Vérifiez : SELECT current_database();   -- doit renvoyer <base>
-- 2. Trouvez le propriétaire des tables (celui qui exécute les migrations Flyway) :
--      SELECT tableowner FROM pg_tables WHERE schemaname = 'public' LIMIT 1;
--    Ce n'est pas forcément l'utilisateur prévu par le projet : vérifiez-le, ne le supposez pas.
-- 3. Remplacez ci-dessous :
--      <base>         : nom de la base du projet       (ex. library)
--      <proprietaire> : résultat de la requête du 2.   (ex. postgres)
--      <mot_de_passe> : mot de passe du rôle claude_ro (ne jamais le commiter)
--
-- pgAdmin exécute tout le script dans une seule transaction : une erreur annule TOUT, y compris le CREATE ROLE.
-- pgAdmin n'affiche que le résultat de la dernière requête : lancez les vérifications une par une.
-- Le mot de passe va ensuite dans la variable d'environnement FACTORY_DB_RO_URI, jamais dans un fichier versionné.

CREATE ROLE claude_ro WITH LOGIN PASSWORD '<mot_de_passe>'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

GRANT CONNECT ON DATABASE <base> TO claude_ro;
GRANT USAGE ON SCHEMA public TO claude_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO claude_ro;

-- Tables créées plus tard par Flyway (nouveaux modules) : lisibles automatiquement.
ALTER DEFAULT PRIVILEGES FOR ROLE <proprietaire> IN SCHEMA public GRANT SELECT ON TABLES TO claude_ro;

-- Sécurité supplémentaire : toute transaction de ce rôle est en lecture seule, et une requête trop longue est coupée.
ALTER ROLE claude_ro SET default_transaction_read_only = on;
ALTER ROLE claude_ro SET statement_timeout = '15s';

-- VÉRIFICATIONS (une requête à la fois) :
--   SET ROLE claude_ro;
--   SELECT count(*) FROM <une_table>;     -- doit réussir
--   DELETE FROM <une_table>;              -- doit échouer : « permission denied » (42501)
--   RESET ROLE;
-- Depuis Claude, une fois le serveur branché :
--   « Lance SELECT current_user, current_setting('default_transaction_read_only') »  → claude_ro, on
--
-- Si le propriétaire est « postgres », l'application tourne en super-utilisateur : à corriger dans le projet
-- (un utilisateur applicatif dédié, propriétaire de ses tables).
