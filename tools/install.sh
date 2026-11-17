#!/usr/bin/env bash
# Installe ou met à jour la Claude Factory dans un projet.
# Fonctionne sous Linux, macOS et Windows (Git Bash).
#
# Première installation :  bash tools/install.sh <projet> --architecture <nom> [--base-branch develop] [--mode plugin|copy]
# Mise à jour du kit     :  bash tools/install.sh <projet> [--mode plugin|copy]
#
#   --mode copy   (défaut) copie le kit dans <projet>/.claude (agents, commandes, skills, hooks, règles).
#   --mode plugin n'écrit que les fichiers du projet ; le kit est fourni par le plugin Claude Code « factory ».
#                 Sur un projet en mode copie, retire les fichiers du kit copiés (migration vers le plugin).
#   --marketplace <owner/repo>  dépôt GitHub de la marketplace (mode plugin ; défaut : dépôt d'origine du kit).
#
# Dans tous les cas, le script :
#  - ne change jamais l'architecture d'un projet existant (.claude/factory.json) ;
#  - conserve la stack du projet (.claude/stack.json) ;
#  - ne touche jamais à .claude/settings.local.json ni au CLAUDE.md du projet ;
#  - réécrit .claude/settings.json (fichier du kit : permissions, et hooks ou activation du plugin) ;
#  - supprime les fichiers que le kit a retirés (tools/removed-files.txt) et signale les autres fichiers inconnus.
set -euo pipefail

kit="$(cd "$(dirname "$0")/.." && pwd)"
refs="$kit/skills/architecture/references"

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
die() { echo "✗ $*" >&2; exit 1; }
info() { echo "• $*"; }
available_architectures() { ls "$refs" | grep -v '^_' | tr '\n' ' '; }

[ $# -ge 1 ] || usage
target="$1"; shift
arch=""; base=""; mode="copy"; marketplace=""
while [ $# -gt 0 ]; do
  case "$1" in
    --architecture) arch="${2:-}"; shift 2 ;;
    --base-branch)  base="${2:-}"; shift 2 ;;
    --mode)         mode="${2:-}"; shift 2 ;;
    --marketplace)  marketplace="${2:-}"; shift 2 ;;
    -h|--help)      usage ;;
    *) die "option inconnue : $1" ;;
  esac
done
case "$mode" in copy|plugin) ;; *) die "--mode doit valoir copy ou plugin (reçu : $mode)" ;; esac

# --- Prérequis ---
command -v git >/dev/null 2>&1 || die "git est introuvable."
if ! command -v jq >/dev/null 2>&1; then
  echo "✗ jq est introuvable : les hooks de la factory en ont besoin (sans lui, les hooks de protection bloquent tout)." >&2
  echo "  Windows : winget install jqlang.jq · macOS : brew install jq · Debian/Ubuntu : sudo apt install jq" >&2
  exit 1
fi
[ -d "$target" ] || die "dossier introuvable : $target"
target="$(cd "$target" && pwd)"
[ "$target" != "$kit" ] || die "le projet cible ne peut pas être le dépôt du kit lui-même."

version="$(jq -r .version "$kit/.claude-plugin/plugin.json")"
plugin_name="$(jq -r .name "$kit/.claude-plugin/plugin.json")"
market_name="$(jq -r .name "$kit/.claude-plugin/marketplace.json")"
if [ -z "$marketplace" ]; then
  url="$(git -C "$kit" remote get-url origin 2>/dev/null || true)"
  marketplace="$(printf '%s' "$url" | sed -nE 's#^.*github\.com[:/]([^/]+/[^/.]+)(\.git)?/?$#\1#p')"
  [ -n "$marketplace" ] || marketplace="babatop2313/factory-dev"
fi
cfg="$target/.claude/factory.json"
stack="$target/.claude/stack.json"
was_copy=0; [ -f "$target/.claude/hooks/session-start.sh" ] && was_copy=1

# --- Installation ou mise à jour ---
if [ -f "$cfg" ]; then
  action="update"
  current="$(jq -r '.architecture // empty' "$cfg" | tr -d '\r')"
  [ -n "$current" ] || die "$cfg existe mais ne contient pas d'architecture. Corrigez-le à la main."
  if [ -n "$arch" ] && [ "$arch" != "$current" ]; then
    die "le projet utilise l'architecture « $current » : on ne change pas d'architecture en cours de projet."
  fi
  arch="$current"
  [ -d "$refs/$arch" ] || die "l'architecture « $arch » du projet n'existe pas dans cette version du kit."
  previous="$(head -1 "$target/.claude/factory-version" 2>/dev/null | tr -d '\r[:space:]' || true)"
  [ -n "$previous" ] || previous="$(jq -r '.factoryVersion // empty' "$cfg" | tr -d '\r')"
  info "Mise à jour : ${previous:-plugin} → $version, mode $mode (architecture : $arch)"
else
  action="install"
  [ -n "$arch" ] || die "première installation : précisez --architecture <nom>. Disponibles : $(available_architectures)"
  [ -d "$refs/$arch" ] && [ "${arch#_}" = "$arch" ] || die "architecture inconnue : $arch. Disponibles : $(available_architectures)"
  info "Installation du kit $version, mode $mode (architecture : $arch)"
fi

# --- Le kit au format .claude/ (référence pour la copie et pour reconnaître les fichiers du kit) ---
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/hooks" "$stage/rules"
cp -R "$kit/agents" "$kit/commands" "$kit/skills" "$stage/"
cp "$kit"/hooks/scripts/*.sh "$stage/hooks/"
cp "$kit/rules/factory.md" "$stage/rules/factory.md"
printf '%s\n' "$version" > "$stage/factory-version"

# --- .claude/settings.json : permissions du kit + hooks (copie) ou activation du plugin (plugin) ---
mkdir -p "$target/.claude"
if [ "$mode" = "copy" ]; then
  jq -s '.[0] * {hooks: (.[1].hooks | walk(if type == "string"
           then gsub("\\$\\{CLAUDE_PLUGIN_ROOT\\}/hooks/scripts/"; "$CLAUDE_PROJECT_DIR/.claude/hooks/") else . end))}' \
    "$kit/templates/settings.json" "$kit/hooks/hooks.json" > "$target/.claude/settings.json"
else
  jq --arg m "$market_name" --arg repo "$marketplace" --arg p "$plugin_name@$market_name" \
    '. + {extraKnownMarketplaces: {($m): {source: {source: "github", repo: $repo}}}, enabledPlugins: {($p): true}}' \
    "$kit/templates/settings.json" > "$target/.claude/settings.json"
fi

# --- Fichiers du kit : copiés (copie) ou retirés du projet (plugin) ---
if [ "$mode" = "copy" ]; then
  cp -R "$stage/." "$target/.claude/"
else
  removed=0
  while IFS= read -r f; do
    rel="${f#"$stage"/}"
    if [ -f "$target/.claude/$rel" ]; then rm -f "$target/.claude/$rel"; removed=$((removed + 1)); fi
  done < <(find "$stage" -type f)
  find "$target/.claude" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  [ "$removed" -gt 0 ] && info "Migration vers le plugin : $removed fichiers du kit retirés de .claude/ (ils viennent maintenant du plugin)."
fi

# --- factory.json et stack.json : créés s'ils manquent, jamais écrasés ---
if [ ! -f "$cfg" ]; then
  printf '{\n  "architecture": "%s",\n  "baseBranch": "%s"\n}\n' "$arch" "${base:-develop}" > "$cfg"
fi
if jq -e 'has("factoryVersion") or (has("baseBranch") | not)' "$cfg" >/dev/null; then
  tmp="$(mktemp)"
  jq --arg b "${base:-develop}" 'del(.factoryVersion) | .baseBranch = (.baseBranch // $b)' "$cfg" > "$tmp"
  mv "$tmp" "$cfg"
  info "factory.json migré (version retirée, baseBranch = $(jq -r .baseBranch "$cfg"))."
fi
if [ ! -f "$stack" ]; then
  cp "$kit/templates/stack.json" "$stack"
  info "stack.json créé (profil « top », intégration « postgresql ») : vérifiez qu'il correspond au projet."
fi

# --- Fichiers retirés du kit par une version précédente : supprimés (ils appartenaient au kit) ---
while read -r ver path; do
  case "$ver" in ''|\#*) continue ;; esac
  path="${path%$'\r'}"
  if [ -f "$target/$path" ]; then
    rm -f "$target/$path"
    rmdir "$(dirname "$target/$path")" 2>/dev/null || true
    info "Supprimé (retiré du kit en v$ver) : $path"
  fi
done < "$kit/tools/removed-files.txt"

# --- Fichiers inconnus dans les dossiers du kit (signalés, jamais supprimés) ---
obsolete=""
for dir in agents commands hooks rules skills; do
  [ -d "$target/.claude/$dir" ] || continue
  while IFS= read -r f; do
    rel="${f#"$target"/.claude/}"
    [ -e "$stage/$rel" ] || obsolete="$obsolete\n    .claude/$rel"
  done < <(find "$target/.claude/$dir" -type f)
done

# --- Fichiers du projet ---
if [ ! -f "$target/CLAUDE.md" ]; then
  cp "$kit/CLAUDE.template.md" "$target/CLAUDE.md"
  info "CLAUDE.md créé à partir du modèle : complétez-le (contexte, règles métier, commandes)."
fi
mkdir -p "$target/docs/specs"
touch "$target/.gitattributes"
for line in '*.sh    text eol=lf' '*.conf  text eol=lf'; do
  grep -qxF "$line" "$target/.gitattributes" || printf '%s\n' "$line" >> "$target/.gitattributes"
done

echo
echo "✓ Kit $version installé dans $target (mode $mode)"
if [ -n "$obsolete" ]; then
  echo
  if [ "$mode" = "plugin" ]; then
    echo "ℹ Ces fichiers propres au projet restent dans .claude/ (ils s'ajoutent au plugin) :"
  else
    echo "⚠ Ces fichiers du projet n'existent pas dans le kit (non supprimés : vérifiez s'ils sont encore utiles) :"
  fi
  printf '%b\n' "${obsolete#\\n}"
fi
echo
echo "Étapes suivantes :"
if [ "$mode" = "plugin" ]; then
  echo "  1. Dans Claude Code, une fois par poste :"
  echo "       /plugin marketplace add $marketplace"
  echo "       /plugin install $plugin_name@$market_name"
  echo "     (les membres de l'équipe sont invités à l'installer grâce à .claude/settings.json)"
  echo "  2. Relancez Claude Code et demandez-lui la version du kit annoncée au démarrage."
fi
if [ "$action" = "install" ]; then
  echo "  • Complétez CLAUDE.md, puis : /init-architecture <premier-module>"
else
  echo "  • Lisez le CHANGELOG du kit (section « À faire dans un projet existant »), puis si besoin : /update-architecture-test"
fi
echo "  • Commitez les changements dans une branche dédiée (ex. chore/factory-v$version)."
