#!/usr/bin/env bash
# Installe ou met à jour la Top Factory dans un projet.
# Fonctionne sous Linux, macOS et Windows (Git Bash).
#
# Première installation :  bash tools/install.sh <projet> --architecture <nom> [--base-branch develop] [--mode plugin|copy]
#                            [--backend <dossier>] [--frontend <dossier>] [--integrations postgresql,redis]
# Mise à jour du kit     :  bash tools/install.sh <projet> [--mode plugin|copy]
# Détection seule        :  bash tools/install.sh <projet> --detect   (affiche ce que le script trouverait, sans rien écrire)
#
#   --backend / --frontend  dossiers du backend (pom.xml Spring Boot) et du frontend (angular.json), relatifs au projet ;
#                 « . » = racine. Détectés automatiquement s'ils ne sont pas précisés (écrits dans factory.json).
#                 Le backend doit exister. Sans frontend détecté ni demandé : aucun frontend (null) ; un --frontend
#                 vers un dossier qui n'existe pas encore est accepté (frontend à créer).
#   --integrations  intégrations déclarées dans stack.json à sa création (défaut : postgresql).
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

usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
die() { echo "✗ $*" >&2; exit 1; }
info() { echo "• $*"; }
available_architectures() { ls "$refs" | grep -v '^_' | tr '\n' ' '; }

[ $# -ge 1 ] || usage
target="$1"; shift
arch=""; base=""; mode="copy"; marketplace=""; backend=""; frontend=""; integrations=""; detect=0
while [ $# -gt 0 ]; do
  case "$1" in
    --architecture) arch="${2:-}"; shift 2 ;;
    --base-branch)  base="${2:-}"; shift 2 ;;
    --mode)         mode="${2:-}"; shift 2 ;;
    --marketplace)  marketplace="${2:-}"; shift 2 ;;
    --backend)      backend="${2:-}"; shift 2 ;;
    --frontend)     frontend="${2:-}"; shift 2 ;;
    --integrations) integrations="${2:-}"; shift 2 ;;
    --detect)       detect=1; shift ;;
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
  [ -n "$marketplace" ] || marketplace="babatop2313/top-factory"
fi
cfg="$target/.claude/factory.json"
stack="$target/.claude/stack.json"

# --- Dossiers du backend et du frontend ---
safe_rel() { case "$1" in ''|/*|*..*|[A-Za-z]:*|*\\*) return 1 ;; esac; return 0; }
# Dossiers (relatifs au projet, profondeur ≤ 2) contenant un pom.xml Spring Boot, ou un angular.json.
find_dirs() {
  find "$target" -maxdepth 3 \( -name node_modules -o -name .git -o -name target -o -name .claude \) -prune -o -name "$1" -print 2>/dev/null \
    | while IFS= read -r f; do
        [ "$1" = pom.xml ] && { grep -q 'spring-boot' "$f" 2>/dev/null || continue; }
        d="$(dirname "$f")"; d="${d#"$target"}"; d="${d#/}"; printf '%s\n' "${d:-.}"
      done | sort
}
backends="$(find_dirs pom.xml)"
frontends="$(find_dirs angular.json)"
# Un projet Maven multi-modules : on garde le dossier le plus haut (le parent), pas chaque module.
backends="$(printf '%s\n' "$backends" | awk 'NF { for (i in seen) if (index($0, i "/") == 1 || i == ".") next; seen[$0]=1; print }')"
if [ "$detect" = 1 ]; then
  echo "projet : $target"
  echo "git : $(git -C "$target" rev-parse --is-inside-work-tree 2>/dev/null || echo non)"
  echo "factory.json : $([ -f "$cfg" ] && jq -c . "$cfg" || echo absent)"
  echo "backend : $(printf '%s' "$backends" | tr '\n' ' ')"
  echo "frontend : $(printf '%s' "$frontends" | tr '\n' ' ')"
  at="$(find "$target" -maxdepth 8 \( -name node_modules -o -name .git -o -name target \) -prune -o -path '*/src/test/java/*' -name ArchitectureTest.java -print 2>/dev/null | head -1)"
  if [ -n "$at" ]; then
    echo "ArchitectureTest : ${at#"$target"/} ($(head -1 "$at" | tr -d '\r' | sed -n 's#^// architecture: *##p'))"
  else
    echo "ArchitectureTest : absent"
  fi
  echo "architectures : $(available_architectures)"
  echo "integrations : $(ls "$kit/skills/integrations/references" | grep -v '^_' | tr '\n' ' ')"
  exit 0
fi
pick_dir() { # <type> <valeur demandée> <candidats> <défaut>
  local kind="$1" want="$2" cands="$3" def="$4" n
  if [ -n "$want" ]; then
    want="${want%/}"
    safe_rel "$want" || die "--$kind « $want » : chemin relatif au projet attendu (ni absolu, ni « .. »)."
    if [ ! -d "$target/$want" ]; then
      [ "$kind" = frontend ] || die "--$kind « $want » : dossier introuvable dans $target."
      echo "• frontend « $want » : dossier à créer (il n'existe pas encore)." >&2
    fi
    printf '%s' "$want"; return
  fi
  n="$(printf '%s' "$cands" | grep -c . || true)"
  case "$n" in
    0) printf '%s' "$def" ;;
    1) printf '%s' "$cands" ;;
    *) die "plusieurs dossiers $kind possibles : $(printf '%s' "$cands" | tr '\n' ' ')— précisez --$kind <dossier>." ;;
  esac
}
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
  for kind in backend frontend; do
    eval "want=\$$kind"
    [ -n "$want" ] || continue
    have="$(jq -r --arg k "$kind" '.[$k] // empty' "$cfg" | tr -d '\r')"
    if [ -n "$have" ] && [ "$have" != "${want%/}" ]; then
      die "factory.json indique déjà $kind = « $have » : modifiez-le à la main si le dossier a vraiment changé."
    fi
  done
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

# --- Vérifications avant toute écriture : dossiers et intégrations ---
if [ "$action" = "install" ]; then
  backend="$(pick_dir backend "$backend" "$backends" backend)"
  frontend="$(pick_dir frontend "$frontend" "$frontends" "")"
fi
if [ -n "$integrations" ] && [ ! -f "$stack" ]; then
  for i in $(printf '%s' "$integrations" | tr ',' ' '); do
    [ -f "$kit/skills/integrations/references/$i/REFERENCE.md" ] && [ "${i#_}" = "$i" ] \
      || die "intégration inconnue : $i. Disponibles : $(ls "$kit/skills/integrations/references" | grep -v '^_' | tr '\n' ' ')"
  done
fi

# --- Le kit au format .claude/ (référence pour la copie et pour reconnaître les fichiers du kit) ---
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/hooks" "$stage/rules"
cp -R "$kit/agents" "$kit/commands" "$kit/skills" "$stage/"
cp "$kit"/hooks/scripts/*.sh "$stage/hooks/"
cp "$kit/rules/factory.md" "$stage/rules/factory.md"
# La commande init n'existe qu'en mode plugin (en copie, elle s'appellerait /init, comme la commande intégrée de Claude Code).
rm -f "$stage/commands/init.md"
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
  jq -n --arg a "$arch" --arg b "${base:-develop}" --arg be "$backend" --arg fe "$frontend" \
    '{architecture: $a, baseBranch: $b, backend: $be, frontend: (if $fe == "" then null else $fe end)}' > "$cfg"
  if [ -n "$frontend" ]; then fe_txt="« $frontend »"; else fe_txt="aucun (à ajouter plus tard avec --frontend)"; fi
  info "factory.json créé : architecture $arch, backend « $backend », frontend $fe_txt."
  [ -f "$target/$backend/pom.xml" ] || echo "⚠ Aucun pom.xml dans « $backend » : générez le backend (start.spring.io) avant /init-architecture."
else
  # Champ absent (projet installé avant la v4.1) ou frontend null : renseigné seulement si demandé.
  for kind in backend frontend; do
    eval "want=\$$kind"
    [ -n "$want" ] || continue
    if jq -e --arg k "$kind" '.[$k] == null' "$cfg" >/dev/null; then
      want="$(pick_dir "$kind" "$want" "" "")"
      tmp="$(mktemp)"; jq --arg k "$kind" --arg v "$want" '.[$k] = $v' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
      info "factory.json : $kind = « $want » ajouté."
    fi
  done
fi
if jq -e 'has("factoryVersion") or (has("baseBranch") | not)' "$cfg" >/dev/null; then
  tmp="$(mktemp)"
  jq --arg b "${base:-develop}" 'del(.factoryVersion) | .baseBranch = (.baseBranch // $b)' "$cfg" > "$tmp"
  mv "$tmp" "$cfg"
  info "factory.json migré (version retirée, baseBranch = $(jq -r .baseBranch "$cfg"))."
fi
if [ ! -f "$stack" ]; then
  if [ -n "$integrations" ]; then
    list="$(printf '%s' "$integrations" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' || true)"
    jq --argjson l "$(printf '%s\n' $list | jq -R . | jq -s .)" '.integrations = $l' "$kit/templates/stack.json" > "$stack"
  else
    cp "$kit/templates/stack.json" "$stack"
  fi
  info "stack.json créé (profil « $(jq -r .profile "$stack") », intégrations : $(jq -r '.integrations | join(", ")' "$stack"))."
elif [ -n "$integrations" ]; then
  info "stack.json existe déjà : --integrations ignoré (ajoutez une technologie avec /add-integration)."
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
  be="$(jq -r '.backend // "backend"' "$cfg" | tr -d '\r')"
  if [ "$be" = "." ]; then
    sed -e 's#(depuis `backend/`)#(depuis la racine du dépôt)#' -e 's#^backend/  #./        #' "$kit/CLAUDE.template.md" > "$target/CLAUDE.md"
  else
    sed "s#backend/#$be/#g" "$kit/CLAUDE.template.md" > "$target/CLAUDE.md"
  fi
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
  if [ "$mode" = "plugin" ]; then
    echo "  • Relancez Claude, complétez CLAUDE.md, puis : /top-factory:init-architecture <premier-module>"
  else
    echo "  • Complétez CLAUDE.md, puis : /init-architecture <premier-module>"
  fi
else
  echo "  • Lisez le CHANGELOG du kit (section « À faire dans un projet existant »), puis si besoin : /update-architecture-test"
fi
echo "  • Commitez les changements dans une branche dédiée (ex. chore/factory-v$version)."
