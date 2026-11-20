---
description: Ouvre le tableau de bord de la factory (tous les projets, leur état, ce qui attend une validation, l'activité récente) et explique les réglages des notifications.
argument-hint: [prune | notifications]
---

Argument (facultatif) : $ARGUMENTS

Le tableau de bord est une page locale, `~/.top-factory/dashboard.html` (ou `$TOP_FACTORY_HOME/dashboard.html`),
régénérée par les hooks de la factory à chaque événement et rechargée toute seule toutes les 15 secondes.
Les données restent sur le poste. `<kit>` est annoncé au début de la session.

1. **Sans argument** : lance `bash "<kit>/hooks/scripts/dashboard.sh" --open` (régénère et ouvre la page dans le
   navigateur), puis résume en quelques lignes, à partir de `~/.top-factory/projects.json` et du dernier événement de
   chaque journal (`~/.top-factory/events/<id>.jsonl`, lu avec l'outil Read) : les projets qui **attendent une action**
   (validation, autorisation, réponse), puis ceux en cours de travail.
2. **`prune`** : lance `bash "<kit>/hooks/scripts/dashboard.sh" --prune` (retire les projets dont le dossier n'existe
   plus) et donne la liste retirée.
3. **`notifications`** : lis `~/.top-factory/config.json` (outil Read) et explique, sans le modifier sans mon accord :
   - `notifications.desktop` (`true`/`false`) : notification du système (Windows, macOS, Linux avec `notify-send`) ;
   - `notifications.events` : événements notifiés — `validation` (arrêt ⏸ d'une commande), `permission` (autorisation
     demandée), `turn_end` (Claude a terminé et rend la main), `attention`, `agent_end`, `commit`, `push` ;
   - `notifications.ntfy` : notifications sur le téléphone avec l'application **ntfy** (gratuite, sans compte) :
     installer l'application, choisir un sujet **long et imprévisible** (il fait office de mot de passe, par exemple
     `top-factory-` suivi d'une vingtaine de caractères aléatoires), s'y abonner dans l'application, puis renseigner
     `topic` (et `server` pour un serveur ntfy personnel). Pour un serveur protégé, le jeton se met dans la variable
     d'environnement `TOP_FACTORY_NTFY_TOKEN`, jamais dans le fichier.
   Les notifications ne contiennent que le nom du projet, l'étape et la branche : jamais de code ni de texte de Claude.
