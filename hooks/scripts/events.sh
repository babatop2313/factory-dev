#!/usr/bin/env bash
# Journal d'activité et notifications de la factory (tableau de bord).
# Appelé par les hooks : events.sh <session_start|session_end|agent_start|agent_end|stop|notification|bash>
#
#  - écrit un événement dans ${TOP_FACTORY_HOME:-~/.top-factory}/events/<projet>.jsonl et inscrit le projet
#    dans projects.json ;
#  - envoie une notification (bureau et/ou ntfy) pour les événements choisis dans config.json ;
#  - régénère le tableau de bord (dashboard.html) en arrière-plan.
# Ne bloque JAMAIS Claude (exit 0 dans tous les cas) et n'écrit RIEN sur la sortie standard
# (pour SessionStart, la sortie serait injectée dans le contexte de Claude).
# Les notifications ne contiennent que le projet, l'étape et la branche : jamais de code ni de texte de Claude.
set -uo pipefail
exec 3>&1 1>/dev/null            # toute sortie accidentelle part dans le vide
source "$(dirname "$0")/lib.sh"
command -v jq >/dev/null 2>&1 || exit 0

kind="${1:-}"
input=$(cat | tr -d '\r')
root=$(project_root)
[ -f "$root/.claude/factory.json" ] || exit 0       # projet sans factory : rien à suivre

home="${TOP_FACTORY_HOME:-$HOME/.top-factory}"
mkdir -p "$home/events" 2>/dev/null || exit 0
name=$(basename "$root")
pid="$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '-')-$(printf '%s' "$root" | cksum | cut -d' ' -f1)"
branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
j() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null | head -c 2000; }
first_line() { printf '%s\n' "$1" | sed -E 's/^[[:space:]#>*]+//' | grep -m1 -v '^[[:space:]]*$' | cut -c1-200; }

title=""; detail=""; ev=""; a=""
case "$kind" in
  session_start)
    ev="session_start"; title="Session ouverte"; detail="$(j .source)" ;;
  session_end)
    ev="session_end"; title="Session fermée"; detail="$(j .reason)" ;;
  agent_start)
    a="$(j .agent_type)"; a="${a##*:}"; ev="agent_start"; title="Agent ${a:-inconnu} au travail" ;;
  agent_end)
    a="$(j .agent_type)"; a="${a##*:}"; ev="agent_end"; title="Agent ${a:-inconnu} a terminé"
    detail="$(first_line "$(j .last_assistant_message)")" ;;
  stop)
    msg="$(j .last_assistant_message)"
    if printf '%s' "$msg" | grep -q '⏸'; then
      ev="validation"; title="Validation requise"
      detail="$(printf '%s\n' "$msg" | grep -m1 '⏸' | sed -E 's/^[[:space:]#>*]+//')"
      detail="${detail#⏸}"; detail="${detail#️}"; detail="$(printf '%s' "$detail" | sed -E 's/^[[:space:]]+//' | cut -c1-200)"
    else
      ev="turn_end"; title="Claude a terminé — à toi de jouer"; detail="$(first_line "$msg")"
    fi ;;
  notification)
    nt="$(j '.notification_type // .type')"; m="$(j .message)"
    case "$nt$m" in
      *permission*) ev="permission"; title="Autorisation demandée"; detail="$m" ;;
      *) ev="attention"; title="Claude attend ta réponse"; detail="$m" ;;
    esac ;;
  bash)
    cmd="$(j .tool_input.command)"
    if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
      ev="commit"; title="Commit"; detail="$(git -C "$root" log -1 --format=%s 2>/dev/null | cut -c1-200)"
    elif printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
      ev="push"; title="Branche poussée"; detail="$branch"
    else
      exit 0
    fi ;;
  *) exit 0 ;;
esac

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
file="$home/events/$pid.jsonl"
jq -cn --arg ts "$ts" --arg k "$ev" --arg t "$title" --arg d "$detail" --arg b "$branch" --arg s "$(j .session_id)" \
  --arg ag "$a" '{ts: $ts, kind: $k, title: $t, detail: $d, branch: $b, session: $s} + (if $ag != "" then {agent: $ag} else {} end)' \
  >> "$file" 2>/dev/null
# Rétention : 1000 derniers événements par projet.
if [ "$(wc -l < "$file" 2>/dev/null | tr -d ' ')" -gt 1200 ]; then
  tail -n 1000 "$file" > "$file.tmp" 2>/dev/null && mv "$file.tmp" "$file"
fi

# --- Registre des projets ---
reg="$home/projects.json"
[ -s "$reg" ] || printf '{}' > "$reg"
cfg="$root/.claude/factory.json"
tmp="$reg.$$.tmp"
if jq --arg id "$pid" --arg n "$name" --arg p "$root" --arg ts "$ts" --arg v "$(kit_version)" \
      --slurpfile f "$cfg" \
      '.[$id] = {name: $n, path: $p, lastSeen: $ts, kit: $v,
                 architecture: ($f[0].architecture // ""), backend: ($f[0].backend // "backend"),
                 baseBranch: ($f[0].baseBranch // "develop"),
                 frontend: (if ($f[0] | has("frontend")) then $f[0].frontend else "frontend" end)}' \
      "$reg" > "$tmp" 2>/dev/null; then
  mv "$tmp" "$reg"
else
  rm -f "$tmp"
fi

# --- Notification ---
conf="$home/config.json"
[ -f "$conf" ] || jq -n '{notifications: {desktop: true, events: ["validation", "permission", "turn_end"],
                          ntfy: {server: "https://ntfy.sh", topic: ""}}}' > "$conf" 2>/dev/null
wanted=$(jq -r --arg k "$ev" '(.notifications.events // ["validation","permission","turn_end"]) | index($k) != null' "$conf" 2>/dev/null)
mode="${TOP_FACTORY_NOTIFY:-on}"                     # on | off | dry (tests : écrit dans notify.log)
if [ "$wanted" = "true" ] && [ "$mode" != "off" ]; then
  ntitle="Top Factory · $name"
  nbody="$title${branch:+ — $branch}"
  topic=$(jq -r '.notifications.ntfy.topic // ""' "$conf" 2>/dev/null)
  server=$(jq -r '.notifications.ntfy.server // "https://ntfy.sh"' "$conf" 2>/dev/null)
  desktop=$(jq -r 'if .notifications.desktop == false then "false" else "true" end' "$conf" 2>/dev/null)
  prio=3; case "$ev" in validation|permission) prio=4 ;; esac
  payload=$(jq -cn --arg tp "$topic" --arg t "$ntitle" --arg m "$nbody" --argjson p "$prio" \
    '{topic: $tp, title: $t, message: $m, priority: $p, tags: ["robot"]}')
  if [ "$mode" = "dry" ]; then
    { [ "$desktop" = "true" ] && echo "desktop|$ntitle|$nbody"; [ -n "$topic" ] && echo "ntfy|${server%/}|$payload"; } >> "$home/notify.log"
  else
    if [ "$desktop" = "true" ]; then
      export TF_TITLE="$ntitle" TF_BODY="$nbody"
      case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
          ( powershell.exe -NoProfile -NonInteractive -Command '
              [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
              $t = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
              $x = $t.GetElementsByTagName("text")
              $x.Item(0).AppendChild($t.CreateTextNode($env:TF_TITLE)) > $null
              $x.Item(1).AppendChild($t.CreateTextNode($env:TF_BODY)) > $null
              $id = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
              [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($id).Show([Windows.UI.Notifications.ToastNotification]::new($t))
            ' >/dev/null 2>&1 & ) ;;
        Darwin)
          ( osascript -e 'display notification (system attribute "TF_BODY") with title (system attribute "TF_TITLE")' >/dev/null 2>&1 & ) ;;
        *)
          command -v notify-send >/dev/null 2>&1 && ( notify-send "$TF_TITLE" "$TF_BODY" >/dev/null 2>&1 & ) ;;
      esac
    fi
    if [ -n "$topic" ] && command -v curl >/dev/null 2>&1; then
      auth=(); [ -n "${TOP_FACTORY_NTFY_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $TOP_FACTORY_NTFY_TOKEN")
      ( curl -s -m 8 ${auth[@]+"${auth[@]}"} -H "Content-Type: application/json" -d "$payload" "${server%/}" >/dev/null 2>&1 & )
    fi
  fi
fi

# --- Tableau de bord, régénéré en arrière-plan ---
if [ "${TOP_FACTORY_DASHBOARD_SYNC:-0}" = "1" ]; then
  bash "$(dirname "$0")/dashboard.sh" >/dev/null 2>&1
else
  ( bash "$(dirname "$0")/dashboard.sh" >/dev/null 2>&1 & )
fi
exit 0
