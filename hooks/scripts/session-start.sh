#!/usr/bin/env bash
# SessionStart : injecte l'architecture active dans le contexte de chaque session.
# Ce que ce script affiche sur la sortie standard est ajouté au contexte de Claude.
# Il ne bloque jamais (exit 0) : en cas de problème, il affiche un avertissement.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

root=$(project_root)                       # chemins Windows normalisés (C:/…)
cfg="$root/.claude/factory.json"
kit=$(kit_root)
refs="$kit/skills/architecture/references"
version=$(kit_version)
mode=$(kit_mode)

# Sans jq, aucun hook ne peut lire ce que Claude Code lui envoie : les protections bloquent tout par sécurité.
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠ TOP FACTORY : jq est introuvable. Les hooks de protection bloqueront toutes les modifications tant qu'il manque."
  echo "Signale-le à l'humain avant toute autre action. $(jq_install_hint)"
  exit 0
fi

if [ ! -f "$cfg" ]; then
  if [ "$mode" = "plugin" ]; then
    # Plugin activé pour tous les projets : ce projet-ci n'utilise peut-être pas la factory. Message court, sans règles.
    echo "ℹ TOP FACTORY ${version:+v$version }est installée mais n'est pas initialisée dans ce projet (.claude/factory.json absent)."
    echo "  Si l'humain veut l'utiliser ici : /top-factory:init. Sinon, ignore ce message : les règles de la factory"
    echo "  ne s'appliquent pas à ce projet. <kit> = $(kit_path "")"
  else
    echo "⚠ TOP FACTORY : .claude/factory.json est absent."
    echo "Aucune architecture n'est configurée. N'écris aucun code backend : demande à l'humain de choisir"
    echo "une architecture parmi : $(ls "$refs" 2>/dev/null | grep -v '^_' | tr '\n' ' ')"
  fi
  exit 0
fi

arch=$(jq -r '.architecture // empty' "$cfg" 2>/dev/null | tr -d '\r')
ref="$refs/$arch/REFERENCE.md"

if [ -z "$arch" ] || [ ! -f "$ref" ]; then
  echo "⚠ TOP FACTORY : l'architecture « $arch » indiquée dans .claude/factory.json n'existe pas."
  echo "N'écris aucun code backend et signale-le à l'humain. Architectures disponibles :"
  echo "$(ls "$refs" 2>/dev/null | grep -v '^_' | tr '\n' ' ')"
  exit 0
fi

base=$(jq -r '.baseBranch // "develop"' "$cfg" 2>/dev/null | tr -d '\r')
echo "=== TOP FACTORY ${version:+v$version }— architecture du projet : $arch (verrouillée dans .claude/factory.json) ==="
if [ "$mode" = "plugin" ]; then
  echo "Kit installé comme plugin Claude Code. Dossier du kit (noté <kit> dans les règles, agents et commandes) :"
else
  echo "Kit copié dans le projet. Dossier du kit (noté <kit> dans les règles, agents et commandes) :"
fi
echo "  <kit> = $(kit_path "")"
brel=$(backend_rel); frel=$(frontend_rel)
echo "Dossiers du projet : <backend> = $brel · <frontend> = ${frel:-aucun} (champs backend et frontend de .claude/factory.json)."
if ! safe_rel "$brel"; then
  echo "⛔ Le dossier backend « $brel » est invalide (chemin absolu ou « .. ») : n'écris aucun code backend et signale-le à l'humain."
elif [ ! -f "$(backend_dir)/pom.xml" ]; then
  echo "⚠ Aucun pom.xml dans « $brel » : le backend est introuvable. Signale-le à l'humain avant toute tâche backend."
fi
if [ -z "$frel" ]; then
  echo "  (aucun frontend déclaré : n'écris pas de code Angular ; pour en créer un : /add-frontend)"
elif ! safe_rel "$frel"; then
  echo "⛔ Le dossier frontend « $frel » est invalide (chemin absolu ou « .. ») : signale-le à l'humain."
elif [ ! -d "$(frontend_dir)" ]; then
  echo "  (pas de frontend dans « $frel » pour l'instant : il se crée par /add-frontend)"
else
  echo "Avant toute tâche frontend, charge le skill « angular-conventions » (socle) et les options front-ui/front-forms du skill « conventions »."
fi
echo "Quand tu délègues à un agent, donne-lui <kit>, <backend>, <frontend> et la référence active : il ne reçoit pas ce message."
echo "Branche d'intégration : $base (les branches feature/* partent de $base à jour)."
echo "Avant toute tâche backend, charge le skill « architecture » et lis en entier :"
echo "  $(kit_path "skills/architecture/references/$arch/REFERENCE.md")"
echo "N'utilise aucune autre référence d'architecture. Ne modifie jamais .claude/factory.json (le lire avec Read est autorisé)."
echo
awk '/^## Résumé[[:space:]]*$/{f=1; next} /^## /{if (f) exit} f' "$ref" | tr -d '\r'

# Stack du projet (.claude/stack.json) : profil de conventions, options, intégrations actives.
stack="$root/.claude/stack.json"
echo
if [ -f "$stack" ]; then
  profile=$(jq -r '.profile // "top"' "$stack" 2>/dev/null | tr -d '\r')
  options=$(jq -r '(.conventions // {}) | to_entries | map("\(.key)=\(.value)") | join(", ")' "$stack" 2>/dev/null | tr -d '\r')
  echo "=== Stack (.claude/stack.json, modifiable avec l'accord de l'humain) ==="
  pfile="$kit/skills/conventions/references/profiles/$profile/PROFILE.md"
  if [ -f "$pfile" ]; then
    # Options effectives : valeur du projet (stack.json) si elle existe, sinon valeur par défaut du profil.
    effective=""
    while IFS='|' read -r opt val; do
      [ -z "$opt" ] && continue
      over=$(jq -r --arg k "$opt" '(.conventions // {})[$k] // empty' "$stack" 2>/dev/null | tr -d '\r')
      if [ -n "$over" ]; then effective+="${effective:+, }$opt=$over (projet)"; else effective+="${effective:+, }$opt=$val"; fi
    done < <(tr -d '\r' < "$pfile" | sed -n 's/^| `\([a-z-]*\)` | `\([^`]*\)` |.*/\1|\2/p')
    echo "Conventions : skill « conventions » (socle + profil « $profile »). À charger avant toute tâche backend."
    [ -n "$effective" ] && echo "Options effectives : $effective."
  else
    echo "Conventions : skill « conventions »${options:+ ; options du projet : $options}."
    echo "⚠ Le profil « $profile » n'existe pas dans $(kit_path "skills/conventions/references/profiles/") : signale-le."
  fi
  integ_list=$(active_integrations)
  if [ -n "$integ_list" ]; then
    echo "Intégrations actives (skill « integrations » : ne lire que la référence de la techno touchée) :"
    for integ in $integ_list; do
      iref="$kit/skills/integrations/references/$integ/REFERENCE.md"
      if [ -f "$iref" ]; then
        status=$(grep -m1 '^> Statut :' "$iref" | sed 's/^> Statut : //' | tr -d '\r')
        summary=$(awk '/^## Résumé[[:space:]]*$/{f=1; next} /^## /{if (f) exit} f && NF {print; exit}' "$iref" | tr -d '\r')
        echo "  - $integ ($status) : $summary"
      else
        echo "  - $integ : ⚠ aucune référence dans $(kit_path "skills/integrations/references/") — signale-le."
      fi
    done
  fi
  echo "Une technologie absente de cette liste ne s'ajoute que par /add-integration <techno>."
else
  echo "ℹ .claude/stack.json est absent (projet installé avant la v3.4) : conventions = socle + profil « top »,"
  echo "  aucune intégration déclarée. Signale à l'humain qu'il peut lancer /top-factory:init pour le créer."
fi

# Ancien format (≤ v3.2) : la version du kit était dans factory.json.
if jq -e 'has("factoryVersion")' "$cfg" >/dev/null 2>&1; then
  echo
  echo "ℹ .claude/factory.json contient encore « factoryVersion » (format v3.2 ou antérieur). Depuis la v3.3, la version"
  echo "  du kit n'est plus dans ce fichier. Signale à l'humain qu'il peut retirer ce champ (et ajouter « baseBranch »)."
  echo "  Ne modifie pas factory.json toi-même : il est verrouillé."
fi

# Mode plugin : un plugin ne peut pas fournir de fichier .claude/rules/ ; les règles communes sont donc injectées ici.
if [ "$mode" = "plugin" ] && [ -f "$kit/rules/factory.md" ]; then
  echo
  tr -d '\r' < "$kit/rules/factory.md" | grep -v '^> '
fi

# Cohérence : un ArchitectureTest généré pour une autre architecture signale un changement d'architecture en cours de projet.
search_root="$root"
bdir=$(backend_dir 2>/dev/null) && [ -d "$bdir" ] && search_root="$bdir"
at=$(find "$search_root" \( -name node_modules -o -name .git -o -name target \) -prune -o \
          -path '*/src/test/java/*' -name ArchitectureTest.java -print 2>/dev/null | head -1)
if [ -n "$at" ]; then
  at=$(norm_path "$at")
  marker=$(head -1 "$at" | tr -d '\r' | sed -n 's#^// architecture: *##p')
  if grep -q '__BASE_PACKAGE__' "$at" 2>/dev/null; then
    echo
    echo "⛔ ArchitectureTest INCOMPLET : ${at#"$root"/} contient encore le marqueur __BASE_PACKAGE__."
    echo "   Les règles concernées analysent un package qui n'existe pas et passent au vert SANS RIEN VÉRIFIER."
    echo "   Signale-le à l'humain et propose de lancer /update-architecture-test avant toute tâche backend."
  fi
  if [ -n "$marker" ] && [ "$marker" != "$arch" ]; then
    echo
    echo "⛔ INCOHÉRENCE : ${at#"$root"/} a été généré pour l'architecture « $marker »,"
    echo "   mais .claude/factory.json indique « $arch ». L'architecture ne peut pas changer en cours de projet."
    echo "   N'écris aucun code backend et signale-le immédiatement à l'humain."
  fi
fi

exit 0
