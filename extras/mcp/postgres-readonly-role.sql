-- Rôle PostgreSQL en LECTURE SEULE pour le serveur MCP (première ligne de défense).
-- À exécuter par un administrateur (ex. postgres), en remplaçant :
--   <base>         : nom de la base du projet            (ex. library)
--   <proprietaire> : rôle qui crée les tables via Flyway (ex. library)
--   <mot_de_passe> : mot de passe du rôle claude_ro       (ne jamais le commiter)
-- Le mot de passe va ensuite dans la variable d'environnement FACTORY_DB_RO_URI, jamais dans un fichier versionné.

CREATE ROLE claude_ro WITH LOGIN PASSWORD '<mot_de_passe>'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

GRANT CONNECT ON DATABASE <base> TO claude_ro;

-- Se connecter à la base <base> avant la suite (psql : \c <base> ; pgAdmin : Query Tool ouvert sur <base>).
GRANT USAGE ON SCHEMA public TO claude_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO claude_ro;

-- Tables créées plus tard par Flyway (nouveaux modules) : lisibles automatiquement.
ALTER DEFAULT PRIVILEGES FOR ROLE <proprietaire> IN SCHEMA public GRANT SELECT ON TABLES TO claude_ro;

-- Sécurité supplémentaire : toute transaction de ce rôle est en lecture seule, et une requête trop longue est coupée.
ALTER ROLE claude_ro SET default_transaction_read_only = on;
ALTER ROLE claude_ro SET statement_timeout = '15s';

-- Vérification (doit échouer avec « permission denied ») :
--   SET ROLE claude_ro; DELETE FROM <une_table>; RESET ROLE;
