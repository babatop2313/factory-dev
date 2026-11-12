#!/usr/bin/env bash
# Installe ou met à jour la Claude Factory dans un projet.
# Fonctionne sous Linux, macOS et Windows (Git Bash).
#
# Première installation :  bash tools/install.sh <dossier-du-projet> --architecture <nom> [--base-branch develop]
# Mise à jour du kit     :  bash tools/install.sh <dossier-du-projet>
#
# Ce que fait le script :
#  - copie le dossier .claude/ du kit dans le projet (les fichiers du kit sont remplacés) ;
#  - ne touche jamais au choix d'architecture d'un projet existant (.claude/factory.json) ;
#  - ne touche jamais à .claude/settings.local.json ni au CLAUDE.md du projet ;
#  - signale, sans les supprimer, les fichiers du projet qui n'existent plus dans le kit.
set -euo pipefail

kit="$(cd "$(dirname "$0")/.." && pwd)"
refs="$kit/.claude/skills/architecture/references"

usage() {
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}
die() { echo "✗ $*" >&2; exit 1; }
info() { echo "• $*"; }

available_architectures() { ls "$refs" | grep -v '^_' | tr '\n' ' '; }

[ $# -ge 1 ] || usage
target="$1"; shift
arch=""; base=""
while [ $# -gt 0 ]; do
  case "$1" in
    --architecture) arch="${2:-}"; shift 2 ;;
    --base-branch)  base="${2:-}"; shift 2 ;;
    -h|--help)      usage ;;
    *) die "option inconnue : $1" ;;
  esac
done

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

cfg="$target/.claude/factory.json"
version="$(head -1 "$kit/.claude/factory-version" | tr -d '\r[:space:]')"

# --- Mode : installation ou mise à jour ---
if [ -f "$cfg" ]; then
  mode="update"
  current="$(jq -r '.architecture // empty' "$cfg" | tr -d '\r')"
  [ -n "$current" ] || die "$cfg existe mais ne contient pas d'architecture. Corrigez-le à la main."
  if [ -n "$arch" ] && [ "$arch" != "$current" ]; then
    die "le projet utilise l'architecture « $current » : on ne change pas d'architecture en cours de projet."
  fi
  arch="$current"
  [ -d "$refs/$arch" ] || die "l'architecture « $arch » du projet n'existe pas dans cette version du kit."
  previous="$(head -1 "$target/.claude/factory-version" 2>/dev/null | tr -d '\r[:space:]' || true)"
  [ -n "$previous" ] || previous="$(jq -r '.factoryVersion // "inconnue"' "$cfg" | tr -d '\r')"
  info "Mise à jour du kit : $previous → $version (architecture : $arch)"
else
  mode="install"
  [ -n "$arch" ] || die "première installation : précisez --architecture <nom>. Disponibles : $(available_architectures)"
  [ -d "$refs/$arch" ] && [ "${arch#_}" = "$arch" ] || die "architecture inconnue : $arch. Disponibles : $(available_architectures)"
  info "Installation du kit $version (architecture : $arch)"
fi

# --- Copie du kit (factory.json du projet sauvegardé puis restauré) ---
saved=""
if [ "$mode" = "update" ]; then
  saved="$(mktemp)"
  cp "$cfg" "$saved"
fi
mkdir -p "$target/.claude"
cp -R "$kit/.claude/." "$target/.claude/"
if [ -n "$saved" ]; then
  cp "$saved" "$cfg"
  rm -f "$saved"
else
  printf '{\n  "architecture": "%s",\n  "baseBranch": "%s"\n}\n' "$arch" "${base:-develop}" > "$cfg"
fi

# --- Migration du format ≤ v3.2 : la version sort de factory.json, baseBranch apparaît ---
if jq -e 'has("factoryVersion") or (has("baseBranch") | not)' "$cfg" >/dev/null; then
  tmp="$(mktemp)"
  jq --arg b "${base:-develop}" 'del(.factoryVersion) | .baseBranch = (.baseBranch // $b)' "$cfg" > "$tmp"
  mv "$tmp" "$cfg"
  info "factory.json migré au format v3.3 (version retirée, baseBranch = $(jq -r .baseBranch "$cfg"))."
fi

# --- Fichiers du projet absents du kit (signalés, jamais supprimés) ---
obsolete=""
for dir in agents commands hooks rules skills; do
  [ -d "$target/.claude/$dir" ] || continue
  while IFS= read -r f; do
    rel="${f#"$target"/.claude/}"
    [ -e "$kit/.claude/$rel" ] || obsolete="$obsolete\n    .claude/$rel"
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
echo "✓ Kit $version installé dans $target"
if [ -n "$obsolete" ]; then
  echo
  echo "⚠ Ces fichiers du projet n'existent plus dans le kit (non supprimés : vérifiez s'ils sont encore utiles) :"
  printf '%b\n' "${obsolete#\\n}"
fi
echo
echo "Étapes suivantes :"
if [ "$mode" = "install" ]; then
  echo "  1. Complétez CLAUDE.md, puis lancez Claude Code à la racine du projet."
  echo "  2. /init-architecture <premier-module>"
else
  echo "  1. Lisez le CHANGELOG du kit (section « À faire dans un projet existant »)."
  echo "  2. Dans Claude Code : /update-architecture-test"
fi
echo "  Pensez à commiter les changements dans une branche dédiée (ex. chore/factory-v$version)."
