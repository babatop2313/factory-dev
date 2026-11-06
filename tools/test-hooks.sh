#!/usr/bin/env bash
# Tests automatiques des hooks de la factory.
# Usage : bash tools/test-hooks.sh   (depuis la racine du dépôt du kit ; Linux, macOS ou Git Bash sous Windows)
# Crée un faux projet temporaire, y copie .claude/, puis simule les appels que Claude Code ferait aux hooks.
set -uo pipefail

kit="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cp -r "$kit/.claude" "$T/"
chmod +x "$T"/.claude/hooks/*.sh
export CLAUDE_PROJECT_DIR="$T"
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"
H="$T/.claude/hooks"
J="$T/backend/src/main/java/com/example/library"
pass=0; fail=0

# chk <code attendu> <libellé> <hook> <json>
chk() {
  local exp=$1 label=$2 hook=$3 json=$4 got
  printf '%s' "$json" | "$H/$hook" >"$T/out" 2>"$T/err"; got=$?
  if [ "$got" -eq "$exp" ]; then pass=$((pass+1)); echo "  ✓ [$got] $label"
  else fail=$((fail+1)); echo "  ✗ [$got, attendu $exp] $label"; sed 's/^/      /' "$T/err" | head -4; fi
}
# chk_out <motif attendu dans stdout> <libellé> <hook> <json>
chk_out() {
  local pat=$1 label=$2 hook=$3 json=$4
  printf '%s' "$json" | "$H/$hook" >"$T/out" 2>"$T/err"
  if grep -q -- "$pat" "$T/out"; then pass=$((pass+1)); echo "  ✓ $label"
  else fail=$((fail+1)); echo "  ✗ $label (sortie attendue : $pat)"; sed 's/^/      /' "$T/out" | head -4; fi
}
setarch() { printf '{ "architecture": "%s" }\r\n' "$1" > "$T/.claude/factory.json"; }   # \r\n : fichier façon Windows
mk() { mkdir -p "$(dirname "$1")"; printf 'package x;\n%s\nclass A{}\n' "$2" > "$1"; }
jp() { printf '{"tool_input":{"file_path":"%s"}}' "$1"; }
jc() { jq -cn --arg c "$1" '{tool_input:{command:$c}}'; }
win() { printf '%s' "$1" | sed 's#/#\\#g'; }

echo "== guard-architecture : hexagonal"
setarch hexagonal
mk "$J/catalog/domain/model/Book.java" 'import jakarta.persistence.Entity;'
chk 2 "domaine + JPA" guard-architecture.sh "$(jp "$J/catalog/domain/model/Book.java")"
chk 2 "domaine + JPA, chemin Windows (\\)" guard-architecture.sh "{\"tool_input\":{\"file_path\":\"$(win "$J/catalog/domain/model/Book.java" | sed 's#\\#\\\\#g')\"}}"
mk "$J/catalog/domain/model/BookId.java" 'import java.util.UUID;'
chk 0 "domaine pur" guard-architecture.sh "$(jp "$J/catalog/domain/model/BookId.java")"
mk "$J/catalog/application/usecase/S.java" 'import com.example.library.catalog.adapter.out.persistence.BookJpaRepository;'
chk 2 "application → adapter" guard-architecture.sh "$(jp "$J/catalog/application/usecase/S.java")"
mk "$J/catalog/application/usecase/Ok.java" 'import com.example.library.shared.UseCase;'
chk 0 "application → shared" guard-architecture.sh "$(jp "$J/catalog/application/usecase/Ok.java")"
mk "$J/catalog/adapter/in/web/C.java" 'import com.example.library.catalog.application.port.out.CheckIsbnRegisteredPort;'
chk 2 "adapter.in → port.out (piège du reviewer)" guard-architecture.sh "$(jp "$J/catalog/adapter/in/web/C.java")"
mk "$J/catalog/adapter/in/web/C2.java" $'import org.springframework.web.bind.annotation.RestController;\nimport com.example.library.catalog.application.port.in.RegisterBookUseCase;'
chk 0 "adapter.in → Spring + port.in" guard-architecture.sh "$(jp "$J/catalog/adapter/in/web/C2.java")"
mk "$J/catalog/api/CatalogApi.java" 'import com.example.library.catalog.domain.model.BookId;'
chk 2 "api → domaine" guard-architecture.sh "$(jp "$J/catalog/api/CatalogApi.java")"
mk "$J/catalog/api/ReservationResult.java" 'import java.util.UUID;'
chk 0 "api → JDK" guard-architecture.sh "$(jp "$J/catalog/api/ReservationResult.java")"
mk "$J/loan/adapter/out/catalog/A.java" 'import com.example.library.catalog.api.CatalogApi;'
chk 0 "loan.adapter.out → catalog.api" guard-architecture.sh "$(jp "$J/loan/adapter/out/catalog/A.java")"
chk 0 "fichier hors src/main/java ignoré" guard-architecture.sh "$(jp "$T/README.md")"

echo "== guard-architecture : couche"
setarch couche
mk "$J/catalog/controller/BookController.java" 'import com.example.library.catalog.repository.BookRepository;'
chk 2 "controller → repository" guard-architecture.sh "$(jp "$J/catalog/controller/BookController.java")"
mk "$J/catalog/controller/C3.java" 'import com.example.library.catalog.entity.Book;'
chk 2 "controller → entity" guard-architecture.sh "$(jp "$J/catalog/controller/C3.java")"
mk "$J/catalog/controller/C4.java" $'import org.springframework.http.ResponseEntity;\nimport com.example.library.catalog.service.BookService;\nimport com.example.library.catalog.dto.BookResponse;'
chk 0 "controller → ResponseEntity + service + dto" guard-architecture.sh "$(jp "$J/catalog/controller/C4.java")"
mk "$J/catalog/service/BookService.java" 'import org.springframework.http.ResponseEntity;'
chk 2 "service → ResponseEntity" guard-architecture.sh "$(jp "$J/catalog/service/BookService.java")"
mk "$J/catalog/entity/B.java" 'import com.example.library.catalog.dto.BookResponse;'
chk 2 "entity → dto" guard-architecture.sh "$(jp "$J/catalog/entity/B.java")"
mk "$J/catalog/repository/R.java" $'import org.springframework.data.jpa.repository.JpaRepository;\nimport com.example.library.catalog.entity.Book;'
chk 0 "repository → Spring Data + entity" guard-architecture.sh "$(jp "$J/catalog/repository/R.java")"

echo "== guard-files"
chk 2 "édition de factory.json" guard-files.sh "$(jp "$T/.claude/factory.json")"
chk 2 "édition de factory.json (chemin Windows)" guard-files.sh '{"tool_input":{"file_path":"C:\\Users\\btop\\proj\\.claude\\factory.json"}}'
chk 2 "fichier .pem" guard-files.sh '{"tool_input":{"file_path":"C:\\Users\\btop\\proj\\cert\\a.pem"}}'
chk 2 "fichier .env" guard-files.sh "$(jp "$T/.env")"
chk 0 "fichier .env.example (modèle autorisé)" guard-files.sh "$(jp "$T/.env.example")"
mkdir -p "$T/backend/src/main/resources/db/migration"; touch "$T/backend/src/main/resources/db/migration/V1__init.sql"
chk 2 "migration existante" guard-files.sh "$(jp "$T/backend/src/main/resources/db/migration/V1__init.sql")"
chk 0 "nouvelle migration" guard-files.sh "$(jp "$T/backend/src/main/resources/db/migration/V2__new.sql")"
chk 0 "fichier ordinaire" guard-files.sh "$(jp "$T/CLAUDE.md")"

echo "== guard-bash : verrou factory.json"
chk 0 "cat factory.json (lecture)" guard-bash.sh "$(jc 'cat .claude/factory.json')"
chk 0 "lecture avec redirection d'erreurs (2>/dev/null)" guard-bash.sh "$(jc 'cat .claude/factory.json 2>/dev/null')"
chk 0 "jq lecture" guard-bash.sh "$(jc 'jq -r .architecture .claude/factory.json')"
chk 0 "copie DEPUIS factory.json" guard-bash.sh "$(jc 'cp .claude/factory.json /tmp/sauvegarde.json')"
chk 2 "echo > factory.json" guard-bash.sh "$(jc 'echo {} > .claude/factory.json')"
chk 2 "sed -i factory.json" guard-bash.sh "$(jc 'sed -i s/couche/hexagonal/ .claude/factory.json')"
chk 2 "copie VERS factory.json" guard-bash.sh "$(jc 'cp /tmp/x.json .claude/factory.json')"
chk 2 "rm factory.json" guard-bash.sh "$(jc 'rm .claude/factory.json')"
chk 2 "git checkout -- factory.json" guard-bash.sh "$(jc 'git checkout -- .claude/factory.json')"
chk 2 "PowerShell Set-Content" guard-bash.sh "$(jc 'Set-Content .claude\factory.json x')"

echo "== guard-bash : migrations"
chk 0 "rm .gitkeep dans db/migration" guard-bash.sh "$(jc 'rm backend/src/main/resources/db/migration/.gitkeep')"
chk 0 "ls db/migration" guard-bash.sh "$(jc 'ls backend/src/main/resources/db/migration')"
chk 2 "rm d'une migration .sql" guard-bash.sh "$(jc 'rm backend/src/main/resources/db/migration/V1__init.sql')"
chk 2 "sed -i d'une migration (chemin Windows)" guard-bash.sh "$(jc 'sed -i s/a/b/ backend\src\main\resources\db\migration\V1__init.sql')"
chk 2 "écriture d'une migration par redirection" guard-bash.sh "$(jc 'echo "create table x();" > backend/src/main/resources/db/migration/V3__x.sql')"

echo "== guard-bash : git et suppressions"
chk 2 "push origin main" guard-bash.sh "$(jc 'git push origin main')"
chk 2 "push origin develop" guard-bash.sh "$(jc 'git push -u origin develop')"
chk 2 "push HEAD:main" guard-bash.sh "$(jc 'git push origin HEAD:main')"
chk 0 "push feature/maintenance (contient « main »)" guard-bash.sh "$(jc 'git push -u origin feature/maintenance')"
chk 0 "push d'une branche feature" guard-bash.sh "$(jc 'git push -u origin feature/enregistrement-livre')"
chk 0 "push d'un tag" guard-bash.sh "$(jc 'git push origin v3.1')"
chk 2 "push --force" guard-bash.sh "$(jc 'git push --force origin feature/x')"
chk 2 "push +branche (forcé)" guard-bash.sh "$(jc 'git push origin +feature/x')"
chk 2 "rm -rf ." guard-bash.sh "$(jc 'rm -rf .')"
chk 0 "rm -rf target" guard-bash.sh "$(jc 'rm -rf backend/target')"

echo "== post-edit-check"
setarch hexagonal
mk "$J/catalog/domain/model/Ok.java" 'import java.util.UUID;'
chk 0 "pas de dossier backend/mvnw ni mvn → pas de blocage" post-edit-check.sh "$(jp "$J/catalog/domain/model/Ok.java")"
if ! command -v mvn >/dev/null 2>&1; then
  rm -f "$TMPDIR"/claude-factory-warn-*
  chk_out "additionalContext" "sans mvnw ni mvn → avertissement non bloquant" post-edit-check.sh "$(jp "$J/catalog/domain/model/Ok.java")"
fi
printf '#!/bin/sh\necho "[ERROR] COMPILATION ERROR :"\necho "[ERROR] /x/Ok.java:[3,1] cannot find symbol"\nexit 1\n' > "$T/backend/mvnw"
chk 2 "erreur de compilation → bloquant" post-edit-check.sh "$(jp "$J/catalog/domain/model/Ok.java")"
printf '#!/bin/sh\necho "curl: Failed to fetch https://repo.maven.apache.org/.../apache-maven-3.10.0-bin.zip"\nexit 1\n' > "$T/backend/mvnw"
rm -f "$TMPDIR"/claude-factory-warn-*
chk 0 "wrapper qui ne démarre pas → non bloquant" post-edit-check.sh "$(jp "$J/catalog/domain/model/Ok.java")"
rm -f "$TMPDIR"/claude-factory-warn-*
chk_out "additionalContext" "wrapper qui ne démarre pas → avertissement" post-edit-check.sh "$(jp "$J/catalog/domain/model/Ok.java")"
printf '#!/bin/sh\nexit 0\n' > "$T/backend/mvnw"
chk 0 "compilation OK" post-edit-check.sh "$(jp "$J/catalog/domain/model/Ok.java")"

echo "== post-bash-check"
chk_out "clean" "rm d'un .java → rappel clean" post-bash-check.sh "$(jc 'rm backend/src/main/java/com/example/library/loan/Triche.java')"
chk_out "clean" "git mv d'un .java → rappel clean" post-bash-check.sh "$(jc 'git mv src/main/java/a/A.java src/main/java/a/B.java')"
chk_out "clean" "Remove-Item d'un dossier source (PowerShell)" post-bash-check.sh "$(jc 'Remove-Item -Recurse backend\src\main\java\com\example\library\loan')"
printf '%s' "$(jc 'ls backend/src/main/java')" | "$H/post-bash-check.sh" >"$T/out" 2>&1
if [ ! -s "$T/out" ]; then pass=$((pass+1)); echo "  ✓ ls → aucun message"; else fail=$((fail+1)); echo "  ✗ ls → message inattendu"; fi
printf '%s' "$(jc 'rm -rf backend/target')" | "$H/post-bash-check.sh" >"$T/out" 2>&1
if [ ! -s "$T/out" ]; then pass=$((pass+1)); echo "  ✓ rm -rf target → aucun message"; else fail=$((fail+1)); echo "  ✗ rm -rf target → message inattendu"; fi

echo "== session-start"
setarch hexagonal
chk_out "architecture du projet : hexagonal" "annonce l'architecture (factory.json en CRLF)" session-start.sh '{}'
chk_out "Architecture active : hexagonale" "injecte le résumé de la référence" session-start.sh '{}'
mv "$T/.claude/factory.json" "$T/fj"
chk_out "factory.json est absent" "factory.json absent" session-start.sh '{}'
mv "$T/fj" "$T/.claude/factory.json"
setarch clean
chk_out "n'existe pas" "architecture inconnue" session-start.sh '{}'
setarch couche
mkdir -p "$T/backend/src/test/java/com/example/library"
printf '// architecture: hexagonal\r\npackage x;\n' > "$T/backend/src/test/java/com/example/library/ArchitectureTest.java"
chk_out "INCOHÉRENCE" "ArchitectureTest d'une autre architecture" session-start.sh '{}'
printf '// architecture: couche\npackage __BASE_PACKAGE__;\n' > "$T/backend/src/test/java/com/example/library/ArchitectureTest.java"
chk_out "INCOMPLET" "ArchitectureTest avec __BASE_PACKAGE__ oublié" session-start.sh '{}'
printf '// architecture: hexagonal\r\npackage x;\n' > "$T/backend/src/test/java/com/example/library/ArchitectureTest.java"
CLAUDE_PROJECT_DIR="$(printf '%s' "$T" | sed 's#^/\(.\)/#\1:/#')" \
  chk_out "INCOHÉRENCE" "racine au format Git Bash / Windows" session-start.sh '{}'

echo
echo "RÉSULTAT : $pass OK, $fail KO"
[ "$fail" -eq 0 ]
