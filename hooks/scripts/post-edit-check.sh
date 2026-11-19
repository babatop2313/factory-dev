#!/usr/bin/env bash
# PostToolUse (Edit|Write) : retour technique immédiat après chaque modification.
#  - .java : compilation Maven du module backend (./mvnw, sinon mvn)
#  - .ts/.html/.scss du frontend : Prettier sur le fichier ; pour un .ts, vérification des types (tsc --noEmit)
# Les règles de dépendance sont vérifiées séparément par guard-architecture.sh (Java) et guard-frontend.sh (Angular).
#
# Retours à Claude :
#  - erreur de compilation         → exit 2 (bloquant : Claude doit corriger)
#  - Maven indisponible / en panne → avertissement NON bloquant (additionalContext), une fois par heure au plus
set -uo pipefail
source "$(dirname "$0")/lib.sh"
need_jq skip

file=$(norm_path "$(jq -r '.tool_input.file_path // ""')")
root=$(project_root)

[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0
# Projet sans factory (plugin activé pour tous les projets, mais pas initialisé ici) : rien à vérifier.
[ -f "$root/.claude/factory.json" ] || exit 0

# Avertissement non bloquant, limité à une fois par heure pour ne pas noyer Claude.
warn_once() {
  local key marker
  key=$(printf '%s' "$root" | cksum | cut -d' ' -f1)
  marker="${TMPDIR:-/tmp}/claude-factory-warn-$key"
  if [ -f "$marker" ] && [ -n "$(find "$marker" -mmin -60 2>/dev/null)" ]; then
    return 0
  fi
  touch "$marker" 2>/dev/null || true
  post_tool_context "$1"
}

case "$file" in
  *.java)
    brel=$(backend_rel)
    if ! backend=$(backend_dir); then
      warn_once "TOP FACTORY : le dossier backend déclaré dans .claude/factory.json (« $brel ») est invalide (chemin absolu ou « .. »). La compilation après chaque modification n'est PAS vérifiée : signale-le à l'humain."
      exit 0
    fi
    if [ ! -d "$backend" ]; then
      warn_once "TOP FACTORY : le dossier backend « $brel » (.claude/factory.json) est introuvable. La compilation après chaque modification n'est PAS vérifiée : signale-le à l'humain."
      exit 0
    fi
    if [ -f "$backend/mvnw" ]; then
      mvn_cmd=(sh ./mvnw)
    elif command -v mvn >/dev/null 2>&1; then
      mvn_cmd=(mvn)
    else
      warn_once "TOP FACTORY : ni $brel/mvnw ni mvn n'est disponible, la compilation après chaque modification n'est PAS vérifiée. Compile toi-même (./mvnw -q compile) avant de déclarer la tâche terminée, et signale-le à l'humain."
      exit 0
    fi

    out=$(cd "$backend" && "${mvn_cmd[@]}" -q -o compile 2>&1)
    rc=$?
    [ $rc -eq 0 ] && exit 0

    if printf '%s' "$out" | grep -qE 'COMPILATION ERROR|\.java:\[[0-9]+'; then
      echo "La compilation échoue après la modification de ${file#"$root"/} :" >&2
      printf '%s\n' "$out" | grep -E '\.java:\[[0-9]+|ERROR\]   |symbol:|location:' | head -25 >&2
      exit 2
    fi

    # Échec qui n'est pas une erreur de code : wrapper qui ne démarre pas, réseau, dépendance absente en mode hors ligne…
    first=$(printf '%s\n' "$out" | grep -m1 -E 'ERROR|Error|error|Failed|failed' || printf '%s\n' "$out" | head -1)
    warn_once "TOP FACTORY : la compilation n'a pas pu être lancée (${mvn_cmd[*]} -q -o compile) — ce n'est pas une erreur dans le code. Cause probable : Maven ou le wrapper ne démarre pas, ou une dépendance n'est pas encore téléchargée (mode hors ligne). Premier message : ${first:0:300}. Lance ./mvnw -q compile sans -o pour vérifier, et signale-le à l'humain si le problème persiste."
    exit 0 ;;
  *.ts|*.html|*.scss)
    front=$(frontend_dir) || exit 0
    [[ "$file" == "$front"/* ]] || exit 0
    if [ -x "$front/node_modules/.bin/prettier" ]; then
      "$front/node_modules/.bin/prettier" --write "$file" >/dev/null 2>&1 || true
    fi
    # Vérification des types après chaque écriture d'un .ts (équivalent de la compilation Java).
    # Les templates (.html) sont vérifiés par « ng build », lancé par l'agent avant de rendre la main.
    case "$file" in *.ts) ;; *) exit 0 ;; esac
    frel=$(frontend_rel)
    tsc_js="$front/node_modules/typescript/bin/tsc"
    if ! command -v node >/dev/null 2>&1 || [ ! -f "$tsc_js" ]; then
      warn_once "TOP FACTORY : node ou les dépendances du frontend (« $frel/node_modules ») sont absents : les types TypeScript ne sont PAS vérifiés après chaque modification. Lance npm install dans $frel, puis npx ng build avant de déclarer la tâche terminée."
      exit 0
    fi
    case "$file" in *.spec.ts) cfg="tsconfig.spec.json" ;; *) cfg="tsconfig.app.json" ;; esac
    [ -f "$front/$cfg" ] || cfg="tsconfig.json"
    [ -f "$front/$cfg" ] || exit 0
    out=$(cd "$front" && node "node_modules/typescript/bin/tsc" --noEmit -p "$cfg" 2>&1)
    rc=$?
    [ $rc -eq 0 ] && exit 0
    if printf '%s' "$out" | grep -qE 'error TS[0-9]+'; then
      echo "Erreurs TypeScript après la modification de ${file#"$root"/} (tsc --noEmit -p $cfg) :" >&2
      printf '%s\n' "$out" | grep -E 'error TS[0-9]+' | head -20 >&2
      exit 2
    fi
    warn_once "TOP FACTORY : la vérification TypeScript n'a pas pu être lancée dans « $frel » — ce n'est pas une erreur dans le code. Premier message : $(printf '%s' "$out" | head -1 | cut -c1-300). Lance npx ng build pour vérifier."
    exit 0 ;;
esac

exit 0
