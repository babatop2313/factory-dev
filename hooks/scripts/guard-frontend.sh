#!/usr/bin/env bash
# PostToolUse (Edit|Write) : vérifie les règles de dépendance du frontend après chaque écriture d'un .ts
# de <frontend>/src/app/ (hors tests *.spec.ts).
# Règles : <kit>/skills/angular-conventions/references/rules.conf, plus l'interdiction d'importer une autre feature
# (features/<a> → features/<b>), vérifiée ici sur les chemins d'import résolus.
# exit 2 = le message (stderr) est renvoyé à Claude, qui corrige dans la foulée.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
need_jq block

file=$(norm_path "$(jq -r '.tool_input.file_path // ""' | tr -d '\r')")
root=$(project_root)

[[ "$file" == *.ts ]] || exit 0
[[ "$file" == *.spec.ts ]] && exit 0
[ -f "$root/.claude/factory.json" ] || exit 0
front=$(frontend_dir) || exit 0
[[ "$file" == "$front"/src/app/* ]] || exit 0
[ -f "$file" ] || exit 0

app_rel="app/${file#"$front"/src/app/}"      # ex. app/features/catalog/pages/book-list.ts
shown="${file#"$root"/}"
rules="$(kit_root)/skills/angular-conventions/references/rules.conf"
violations=""

# --- Règles par segment (rules.conf) ---
if [ -f "$rules" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    segment="${line%% :: *}"
    rest="${line#* :: }"
    regex="${rest%% :: *}"
    message="${rest#* :: }"
    [[ "/$app_rel" == */"$segment"/* ]] || continue
    bad=$(tr -d '\r' < "$file" | grep -nE "$regex" || true)
    [ -n "$bad" ] && violations+="• « $segment » : $message"$'\n'"$bad"$'\n'
  done < "$rules"
fi

# --- Pas de HttpClient dans un composant, une directive ou un pipe, quel que soit son dossier ---
content=$(tr -d '\r' < "$file")
if printf '%s\n' "$content" | grep -qE '^[[:space:]]*@(Component|Directive|Pipe)\('; then
  bad=$(printf '%s\n' "$content" | grep -nE "(^import .*\bHttpClient\b.*from ['\"]@angular/common/http['\"]|inject\([[:space:]]*HttpClient[[:space:]]*\))" || true)
  [ -n "$bad" ] && violations+="• HttpClient dans un composant (ou une directive, un pipe) : l'accès HTTP passe par le service de la feature (data/), que le composant injecte."$'\n'"$bad"$'\n'
fi

# --- Une feature n'importe pas une autre feature ---
# Résout les imports relatifs (./, ../) par rapport au dossier du fichier, puis compare la feature visée.
resolve() {   # $1 = dossier (relatif à src/), $2 = chemin d'import relatif → chemin normalisé
  local path="$1/$2" out="" part
  local IFS='/'
  for part in $path; do
    case "$part" in
      ''|.) ;;
      ..) out="${out%/*}" ;;
      *) out="$out/$part" ;;
    esac
  done
  printf '%s' "${out#/}"
}
case "/$app_rel" in
  */app/features/*)
    own="${app_rel#app/features/}"; own="${own%%/*}"
    dir=$(dirname "$app_rel")
    while IFS= read -r imp; do
      [ -z "$imp" ] && continue
      num="${imp%%:*}"; target="${imp#*:}"
      case "$target" in
        .*) target=$(resolve "$dir" "$target") ;;
        */features/*) target="app/features/${target##*/features/}" ;;
        *) continue ;;
      esac
      case "$target" in
        app/features/*)
          other="${target#app/features/}"; other="${other%%/*}"
          if [ -n "$other" ] && [ "$other" != "$own" ]; then
            violations+="• la feature « $own » importe la feature « $other » : ce qui est partagé va dans shared/ (interface) ou core/ (transverse)."$'\n'"$num: $(sed -n "${num}p" "$file" | tr -d '\r')"$'\n'
          fi ;;
      esac
    done < <(tr -d '\r' < "$file" | grep -nE "^[[:space:]]*(import|export)[^;]*from[[:space:]]*['\"]" \
               | sed -nE "s/^([0-9]+):.*from[[:space:]]*['\"]([^'\"]+)['\"].*/\1:\2/p")
    ;;
esac

if [ -n "$violations" ]; then
  echo "Violation des conventions du frontend dans $shown :" >&2
  printf '%s' "$violations" >&2
  echo "Corrige le code pour respecter $(kit_path "skills/angular-conventions/SKILL.md") (Règles de dépendance)." >&2
  exit 2
fi
exit 0
