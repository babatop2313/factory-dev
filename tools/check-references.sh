#!/usr/bin/env bash
# Vérifie que chaque référence de la factory respecte son contrat :
# architectures (dont roles.conf), intégrations, conventions (socle, profils, options) et stack.json du kit.
# Usage : bash tools/check-references.sh   (depuis la racine du dépôt)
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
refs="$root/.claude/skills/architecture/references"
sections=("Résumé" "Structure des packages" "Règle de dépendance" "Ordre d'implémentation" \
          "Règles du développeur" "Exemples de code" "Tests par couche" "Grille de revue" "Format de réponse finale")
files=("REFERENCE.md" "ArchitectureTest.java" "rules.conf" "scaffold.md" "roles.conf")
vocab="$root/.claude/skills/integrations/roles.conf"
errors=0

# Clés du vocabulaire des rôles techniques
roles_vocab=$(tr -d '\r' < "$vocab" | grep -v '^#' | awk -F ' :: ' 'NF >= 2 {print $1}')
regex_ok() { echo "" | grep -E "$1" >/dev/null 2>&1; [ $? -ne 2 ]; }

echo "### Architectures"
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
      regex_ok "$re" || { echo "   ✗ regex invalide : $re"; errors=$((errors+1)); }
    done < "${dir}rules.conf"
    [ "$n" -gt 0 ] || { echo "   ✗ rules.conf ne contient aucune règle"; errors=$((errors+1)); }
  fi

  if [ -f "${dir}roles.conf" ]; then
    for role in $roles_vocab; do
      line=$(tr -d '\r' < "${dir}roles.conf" | grep -E "^$role :: ")
      if [ -z "$line" ]; then echo "   ✗ roles.conf : rôle manquant « $role »"; errors=$((errors+1)); continue; fi
      [[ "$line" == *" :: "*" :: "* ]] || { echo "   ✗ roles.conf, ligne mal formée : $line"; errors=$((errors+1)); }
      grep -q "\`$role\`" "${dir}REFERENCE.md" 2>/dev/null \
        || { echo "   ✗ REFERENCE.md ne mentionne pas le rôle \`$role\` (sous-section « Rôles techniques »)"; errors=$((errors+1)); }
    done
  fi

  [ "$errors" -eq "$before" ] && echo "   ✓ contrat respecté"
done

echo
echo "### Intégrations"
irefs="$root/.claude/skills/integrations/references"
isections=("Résumé" "Cas d'usage" "Dépendances" "Connexion et configuration" "Rôle dans l'architecture" "Conventions" \
           "Résilience" "Sécurité" "Observabilité" "Développement local" "Tests" "Grille de revue")
for dir in "$irefs"/*/; do
  name="$(basename "$dir")"
  [ "$name" = "_template" ] && continue
  echo "== $name"
  before=$errors
  ref="${dir}REFERENCE.md"; rules="${dir}rules.conf"
  for f in REFERENCE.md rules.conf; do
    [ -f "$dir$f" ] || { echo "   ✗ fichier manquant : $f"; errors=$((errors+1)); }
  done
  if [ -f "$ref" ]; then
    head -1 "$ref" | grep -q '^# Intégration — ' || { echo "   ✗ la première ligne doit être « # Intégration — <Nom> »"; errors=$((errors+1)); }
    grep -qE '^> Statut : (testée|non testée)$' "$ref" || { echo "   ✗ ligne « > Statut : testée » ou « > Statut : non testée » absente"; errors=$((errors+1)); }
    for sct in "${isections[@]}"; do
      grep -qx "## $sct" "$ref" || { echo "   ✗ section manquante : ## $sct"; errors=$((errors+1)); }
    done
    role_section=$(awk "/^## Rôle dans l'architecture[[:space:]]*\$/{f=1; next} /^## /{if (f) exit} f" "$ref")
  fi
  if [ -f "$rules" ]; then
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      [[ -z "$line" || "$line" == \#* ]] && continue
      n=$((n+1))
      [[ "$line" == *" :: "*" :: "* ]] || { echo "   ✗ rules.conf, ligne mal formée : $line"; errors=$((errors+1)); continue; }
      roles="${line%% :: *}"; rest="${line#* :: }"; re="${rest%% :: *}"
      regex_ok "$re" || { echo "   ✗ regex invalide : $re"; errors=$((errors+1)); }
      for role in $(printf '%s' "$roles" | tr ',' ' '); do
        printf '%s\n' $roles_vocab | grep -qx "$role" || { echo "   ✗ rules.conf : rôle inconnu « $role »"; errors=$((errors+1)); continue; }
        printf '%s' "${role_section:-}" | grep -q "\`$role\`" \
          || { echo "   ✗ le rôle \`$role\` de rules.conf n'est pas cité dans « Rôle dans l'architecture »"; errors=$((errors+1)); }
      done
    done < "$rules"
    [ "$n" -gt 0 ] || { echo "   ✗ rules.conf ne contient aucune règle"; errors=$((errors+1)); }
  fi
  [ "$errors" -eq "$before" ] && echo "   ✓ contrat respecté"
done

echo
echo "### Conventions"
conv="$root/.claude/skills/conventions/references"
[ -f "$conv/socle/REFERENCE.md" ] && echo "== socle" && echo "   ✓ présent" \
  || { echo "   ✗ socle/REFERENCE.md manquant"; errors=$((errors+1)); }
options=$(ls "$conv/options" 2>/dev/null | sed -n 's/\.md$//p')
valid_value() {   # $1 = option, $2 = valeur
  [ -f "$conv/options/$1.md" ] && grep -qx "## Valeur : $2" "$conv/options/$1.md"
}
for opt in $options; do
  grep -q '^## Valeur : ' "$conv/options/$opt.md" || { echo "   ✗ options/$opt.md : aucune section « ## Valeur : … »"; errors=$((errors+1)); }
done
for pdir in "$conv"/profiles/*/; do
  pname=$(basename "$pdir")
  echo "== profil $pname"
  before=$errors
  pf="${pdir}PROFILE.md"
  [ -f "$pf" ] || { echo "   ✗ PROFILE.md manquant"; errors=$((errors+1)); continue; }
  for opt in $options; do
    val=$(tr -d '\r' < "$pf" | sed -n "s/^| \`$opt\` | \`\([^\`]*\)\` |.*/\1/p" | head -1)
    if [ -z "$val" ]; then echo "   ✗ pas de valeur par défaut pour l'option « $opt »"; errors=$((errors+1))
    elif ! valid_value "$opt" "$val"; then echo "   ✗ option « $opt » : valeur « $val » sans section dans options/$opt.md"; errors=$((errors+1)); fi
  done
  [ "$errors" -eq "$before" ] && echo "   ✓ contrat respecté"
done

echo
echo "### stack.json du kit"
stack="$root/.claude/stack.json"
if jq -e . "$stack" >/dev/null 2>&1; then
  p=$(jq -r '.profile // empty' "$stack")
  [ -f "$conv/profiles/$p/PROFILE.md" ] || { echo "   ✗ profil inconnu : « $p »"; errors=$((errors+1)); }
  for i in $(jq -r '(.integrations // [])[]' "$stack"); do
    [ -f "$irefs/$i/REFERENCE.md" ] || { echo "   ✗ intégration sans référence : « $i »"; errors=$((errors+1)); }
  done
  while IFS='=' read -r k v; do
    [ -z "$k" ] && continue
    valid_value "$k" "$v" || { echo "   ✗ option « $k=$v » inconnue"; errors=$((errors+1)); }
  done < <(jq -r '(.conventions // {}) | to_entries[] | "\(.key)=\(.value)"' "$stack")
  echo "   ✓ vérifié"
else
  echo "   ✗ .claude/stack.json absent ou invalide"; errors=$((errors+1))
fi

active=$(jq -r '.architecture // empty' "$root/.claude/factory.json" 2>/dev/null | tr -d '\r')
if [ -n "$active" ] && [ ! -d "$refs/$active" ]; then
  echo "✗ factory.json désigne « $active », qui n'existe pas dans references/"; errors=$((errors+1))
fi

echo
[ "$errors" -eq 0 ] && { echo "OK : toutes les références respectent le contrat."; exit 0; }
echo "$errors erreur(s)."; exit 1
