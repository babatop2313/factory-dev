#!/usr/bin/env bash
# Vérifie que chaque référence d'architecture respecte le contrat de la factory.
# Usage : bash tools/check-references.sh   (depuis la racine du dépôt)
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
refs="$root/.claude/skills/architecture/references"
sections=("Résumé" "Structure des packages" "Règle de dépendance" "Ordre d'implémentation" \
          "Règles du développeur" "Exemples de code" "Tests par couche" "Grille de revue" "Format de réponse finale")
files=("REFERENCE.md" "ArchitectureTest.java" "rules.conf" "scaffold.md")
errors=0

for dir in "$refs"/*/; do
  name="$(basename "$dir")"
  [ "$name" = "_template" ] && continue
  echo "== $name"
  before=$errors

  for f in "${files[@]}"; do
    [ -f "$dir$f" ] || { echo "   ✗ fichier manquant : $f"; errors=$((errors+1)); }
  done

  if [ -f "${dir}REFERENCE.md" ]; then
    for s in "${sections[@]}"; do
      grep -qx "## $s" "${dir}REFERENCE.md" || { echo "   ✗ section manquante : ## $s"; errors=$((errors+1)); }
    done
  fi

  if [ -f "${dir}ArchitectureTest.java" ]; then
    head -1 "${dir}ArchitectureTest.java" | grep -qx "// architecture: $name" \
      || { echo "   ✗ ArchitectureTest.java doit commencer par « // architecture: $name »"; errors=$((errors+1)); }
    grep -q "__BASE_PACKAGE__" "${dir}ArchitectureTest.java" \
      || { echo "   ✗ ArchitectureTest.java doit utiliser le marqueur __BASE_PACKAGE__"; errors=$((errors+1)); }
  fi

  if [ -f "${dir}rules.conf" ]; then
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      [[ -z "$line" || "$line" == \#* ]] && continue
      n=$((n+1))
      [[ "$line" == *" :: "*" :: "* ]] || { echo "   ✗ rules.conf, ligne mal formée : $line"; errors=$((errors+1)); continue; }
      rest="${line#* :: }"; re="${rest%% :: *}"
      echo "" | grep -E "$re" >/dev/null 2>&1; [ $? -eq 2 ] && { echo "   ✗ regex invalide : $re"; errors=$((errors+1)); }
    done < "${dir}rules.conf"
    [ "$n" -gt 0 ] || { echo "   ✗ rules.conf ne contient aucune règle"; errors=$((errors+1)); }
  fi

  [ "$errors" -eq "$before" ] && echo "   ✓ contrat respecté"
done

active=$(jq -r '.architecture // empty' "$root/.claude/factory.json" 2>/dev/null | tr -d '\r')
if [ -n "$active" ] && [ ! -d "$refs/$active" ]; then
  echo "✗ factory.json désigne « $active », qui n'existe pas dans references/"; errors=$((errors+1))
fi

echo
[ "$errors" -eq 0 ] && { echo "OK : toutes les références respectent le contrat."; exit 0; }
echo "$errors erreur(s)."; exit 1
