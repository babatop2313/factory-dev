#!/usr/bin/env bash
# Fonctions communes aux hooks de la factory. Chargé par : source "$(dirname "$0")/lib.sh"

# jq est indispensable : il lit le JSON envoyé par Claude Code sur l'entrée standard.
# need_jq block → hook de protection : sans jq, on BLOQUE (exit 2) plutôt que de laisser tout passer.
# need_jq skip  → hook de confort : sans jq, on ne fait rien (exit 0).
jq_install_hint() {
  echo "Installez jq : Windows « winget install jqlang.jq » · macOS « brew install jq » · Debian/Ubuntu « sudo apt install jq » · Fedora « sudo dnf install jq »."
}
need_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  if [ "${1:-skip}" = "block" ]; then
    echo "Hook de protection de la factory : jq est introuvable, l'action est bloquée par sécurité." >&2
    jq_install_hint >&2
    exit 2
  fi
  exit 0
}

# Normalise un chemin pour qu'il soit comparable quel que soit l'OS :
#   C:\Users\x\f.java  →  C:/Users/x/f.java
#   /c/Users/x/f.java  →  C:/Users/x/f.java   (forme Git Bash / MSYS)
#   c:/Users/x/f.java  →  C:/Users/x/f.java
norm_path() {
  local p="${1//\\//}"
  p="${p%$'\r'}"
  if [[ "$p" =~ ^/([a-zA-Z])/(.*)$ ]]; then
    p="${BASH_REMATCH[1]}:/${BASH_REMATCH[2]}"
  fi
  if [[ "$p" =~ ^([a-zA-Z]):/(.*)$ ]]; then
    p="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]'):/${BASH_REMATCH[2]}"
  fi
  printf '%s' "$p"
}

# Racine du projet, normalisée.
project_root() {
  norm_path "${CLAUDE_PROJECT_DIR:-$(pwd)}"
}

# Racine du kit, déduite de l'emplacement des scripts (aucune variable d'environnement requise) :
#   mode plugin : <plugin>/hooks/scripts/lib.sh  →  <plugin>
#   mode copie  : <projet>/.claude/hooks/lib.sh  →  <projet>/.claude
FACTORY_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kit_root() {
  local d="$FACTORY_HOOK_DIR"
  if [ "$(basename "$d")" = "scripts" ]; then d="$(dirname "$(dirname "$d")")"; else d="$(dirname "$d")"; fi
  norm_path "$d"
}
# plugin ou copy
kit_mode() {
  [ -f "$(kit_root)/.claude-plugin/plugin.json" ] && echo plugin || echo copy
}
# Version du kit : plugin.json (mode plugin) ou .claude/factory-version (mode copie).
kit_version() {
  local k; k="$(kit_root)"
  if [ -f "$k/.claude-plugin/plugin.json" ]; then
    jq -r '.version // empty' "$k/.claude-plugin/plugin.json" 2>/dev/null | tr -d '\r'
  else
    head -1 "$k/factory-version" 2>/dev/null | tr -d '\r[:space:]'
  fi
}
# Chemin d'un fichier du kit tel qu'on l'affiche : relatif au projet en mode copie, absolu en mode plugin.
kit_path() {
  local k r p; k="$(kit_root)"; r="$(project_root)"
  case "$k" in "$r"/*) p="${k#"$r"/}" ;; *) p="$k" ;; esac
  if [ -n "${1:-}" ]; then printf '%s/%s' "$p" "$1"; else printf '%s' "$p"; fi
}

# Architecture active lue dans .claude/factory.json (vide si absent ou illisible).
active_architecture() {
  jq -r '.architecture // empty' "$(project_root)/.claude/factory.json" 2>/dev/null | tr -d '\r'
}

# Dossiers du backend et du frontend, relatifs à la racine du projet (.claude/factory.json, champs backend et frontend).
# Par défaut « backend » et « frontend » ; « . » désigne la racine du dépôt.
dir_rel() {
  local v
  v=$(jq -r --arg k "$1" '.[$k] // empty' "$(project_root)/.claude/factory.json" 2>/dev/null | tr -d '\r')
  v="${v%/}"
  printf '%s' "${v:-$2}"
}
backend_rel()  { dir_rel backend backend; }
frontend_rel() { dir_rel frontend frontend; }
# Valeur acceptable : chemin relatif, sans « .. » ni chemin absolu (sinon on sortirait du projet).
safe_rel() {
  case "$1" in /*|*..*|[A-Za-z]:*|*\\*) return 1 ;; esac
  return 0
}
dir_abs() {
  local rel="$1"; safe_rel "$rel" || return 1
  if [ "$rel" = "." ]; then project_root; else printf '%s/%s' "$(project_root)" "$rel"; fi
}
backend_dir()  { dir_abs "$(backend_rel)"; }
frontend_dir() { dir_abs "$(frontend_rel)"; }

# Intégrations actives (.claude/stack.json), une par ligne.
active_integrations() {
  jq -r '(.integrations // [])[]' "$(project_root)/.claude/stack.json" 2>/dev/null | tr -d '\r'
}

# Segments de package d'un rôle technique dans l'architecture active (roles.conf), un par ligne.
role_segments() {
  local conf
  conf="$(kit_root)/skills/architecture/references/$(active_architecture)/roles.conf"
  [ -f "$conf" ] || return 0
  tr -d '\r' < "$conf" | awk -F ' :: ' -v r="$1" '$1 == r { n = split($2, a, ","); for (i = 1; i <= n; i++) { gsub(/^ +| +$/, "", a[i]); print a[i] } }'
}

# Retour NON bloquant pour Claude après un outil (PostToolUse) : le texte est ajouté à son contexte.
post_tool_context() {
  jq -n --arg msg "$1" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
}
