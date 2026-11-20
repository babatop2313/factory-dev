#!/usr/bin/env bash
# Génère le tableau de bord de la factory : ${TOP_FACTORY_HOME:-~/.top-factory}/dashboard.html
# Page autonome (aucun serveur, aucune ressource externe) : vue d'ensemble, process de chaque feature, activité,
# documentation de la factory (commandes et agents lus dans le kit). Actualisée toutes les 15 s.
#
#   bash dashboard.sh            régénère la page
#   bash dashboard.sh --open     régénère et l'ouvre dans le navigateur
#   bash dashboard.sh --prune    retire du registre les projets dont le dossier n'existe plus
#   bash dashboard.sh --path     affiche le chemin de la page
# Icônes : Lucide (https://lucide.dev), licence ISC.
set -uo pipefail
command -v jq >/dev/null 2>&1 || { echo "jq est requis pour le tableau de bord." >&2; exit 1; }
source "$(dirname "$0")/lib.sh"

home="${TOP_FACTORY_HOME:-$HOME/.top-factory}"
reg="$home/projects.json"
out="$home/dashboard.html"
mkdir -p "$home/events"
[ -s "$reg" ] || printf '{}' > "$reg"

case "${1:-}" in
  --path) echo "$out"; exit 0 ;;
  --prune)
    tmp="$reg.$$.tmp"; keep='{}'
    for id in $(jq -r 'keys[]' "$reg"); do
      p=$(jq -r --arg id "$id" '.[$id].path' "$reg")
      if [ -d "$p" ]; then keep=$(printf '%s' "$keep" | jq --arg id "$id" --slurpfile r "$reg" '.[$id] = $r[0][$id]')
      else echo "Retiré : $(jq -r --arg id "$id" '.[$id].name' "$reg") ($p)"; fi
    done
    printf '%s\n' "$keep" > "$tmp" && mv "$tmp" "$reg" ;;
esac

# --- Projets : registre + 300 derniers événements + specs + Git ---
projects="[]"
for id in $(jq -r 'keys[]' "$reg" 2>/dev/null); do
  p=$(jq -r --arg id "$id" '.[$id].path' "$reg")
  ev="[]"
  [ -f "$home/events/$id.jsonl" ] && ev=$(tail -n 300 "$home/events/$id.jsonl" | jq -cs '[.[] | objects]' 2>/dev/null || echo "[]")
  exists=false; specs="[]"; br=""; last=""
  if [ -d "$p" ]; then
    exists=true
    br=$(git -C "$p" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    last=$(git -C "$p" log -1 --format='%s|%cI' 2>/dev/null | cut -c1-200 || true)
    if [ -d "$p/docs/specs" ]; then
      specs=$(for f in "$p"/docs/specs/*.md; do
                [ -f "$f" ] || continue
                printf '%s\t%s\n' "$(basename "$f")" "$(date -r "$f" +%s 2>/dev/null || echo 0)"
              done | sort -t"$(printf '\t')" -k2 -nr | head -20 \
              | jq -Rcs 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], mtime: (.[1] | tonumber)})')
    fi
  fi
  projects=$(jq -c --arg id "$id" --slurpfile r "$reg" --argjson ev "$ev" --argjson specs "$specs" \
                --argjson exists "$exists" --arg br "$br" --arg last "$last" \
    '. + [$r[0][$id] + {id: $id, exists: $exists, branch: $br, lastCommit: $last, specs: $specs, events: $ev}]' \
    <<< "$projects")
done

# --- Documentation : commandes et agents lus dans le kit (toujours à jour) ---
kit=$(kit_root)
front() { awk -v k="$2" 'NR==1 && /^---/ {f=1; next} f && /^---/ {exit} f && index($0, k ":") == 1 {sub("^" k ":[[:space:]]*", ""); print; exit}' "$1" | tr -d '\r'; }
docs_list() {
  for f in "$kit/$1"/*.md; do
    [ -f "$f" ] || continue
    printf '%s\t%s\t%s\n' "$(basename "$f" .md)" "$(front "$f" description)" "$(front "$f" argument-hint)"
  done | jq -Rcs 'split("\n") | map(select(length > 0) | split("\t")
         | {name: .[0], description: ((.[1] // "") | gsub("^\"|\"$"; "")), hint: ((.[2] // "") | gsub("^\"|\"$"; ""))})'
}
prefix="/"; [ "$(kit_mode)" = "plugin" ] && prefix="/top-factory:"
user=$(git config --global user.name 2>/dev/null | awk '{print $1}')
[ -n "$user" ] || user="${USERNAME:-${USER:-}}"
data=$(jq -cn --argjson p "$projects" --arg g "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg v "$(kit_version)" \
          --arg prefix "$prefix" --arg user "$user" --arg home "$home" \
          --argjson commands "$(docs_list commands)" --argjson agents "$(docs_list agents)" \
          '{generated: $g, kit: $v, prefix: $prefix, user: $user, home: $home,
            projects: $p, docs: {commands: $commands, agents: $agents}}' \
       | sed 's#</#<\\/#g')

tmp="$out.$$.tmp"
{
cat <<'TF_HTML_END'
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Top Factory</title>
<script>try { var t = localStorage.getItem('tf-theme'); if (t === 'light' || t === 'dark') document.documentElement.setAttribute('data-theme', t); } catch (e) {}</script>
<style>
  :root {
    --bg: #f5f6f8; --surface: #ffffff; --surface-2: #f9fafb; --text: #111827; --text-2: #4b5563; --text-3: #9ca3af;
    --line: #e5e7eb; --accent: #4f46e5; --accent-soft: #eef2ff;
    --amber: #b45309; --amber-soft: #fef3c7; --sky: #0369a1; --sky-soft: #e0f2fe;
    --emerald: #047857; --emerald-soft: #d1fae5; --slate: #64748b; --slate-soft: #f1f5f9; --rose: #be123c; --rose-soft: #ffe4e6;
    --shadow: 0 1px 2px rgba(16,24,40,.04), 0 1px 3px rgba(16,24,40,.06);
    --radius: 14px;
  }
  :root[data-theme="dark"] {
      --bg: #0b0d12; --surface: #141821; --surface-2: #1a1f2a; --text: #f3f4f6; --text-2: #c2c8d2; --text-3: #7c8594;
      --line: #262c38; --accent: #a5b4fc; --accent-soft: #1e1b4b;
      --amber: #fbbf24; --amber-soft: #3a2a08; --sky: #7dd3fc; --sky-soft: #0c2a3d;
      --emerald: #6ee7b7; --emerald-soft: #0b2e22; --slate: #94a3b8; --slate-soft: #1c2230; --rose: #fda4af; --rose-soft: #3b0f1a;
      --shadow: 0 1px 2px rgba(0,0,0,.3);
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --bg: #0b0d12; --surface: #141821; --surface-2: #1a1f2a; --text: #f3f4f6; --text-2: #c2c8d2; --text-3: #7c8594;
      --line: #262c38; --accent: #a5b4fc; --accent-soft: #1e1b4b;
      --amber: #fbbf24; --amber-soft: #3a2a08; --sky: #7dd3fc; --sky-soft: #0c2a3d;
      --emerald: #6ee7b7; --emerald-soft: #0b2e22; --slate: #94a3b8; --slate-soft: #1c2230; --rose: #fda4af; --rose-soft: #3b0f1a;
      --shadow: 0 1px 2px rgba(0,0,0,.3);
    }
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; }
  body { font: 15px/1.55 ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
         background: var(--bg); color: var(--text); -webkit-font-smoothing: antialiased; }
  a { color: inherit; }
  .icon { width: 18px; height: 18px; flex: none; stroke-width: 1.8; }
  .icon.sm { width: 15px; height: 15px; } .icon.lg { width: 22px; height: 22px; }
  .app { display: grid; grid-template-columns: 248px 1fr; min-height: 100vh;
         background: linear-gradient(to right, var(--surface) 247px, var(--line) 247px, var(--line) 248px, var(--bg) 248px); }
  aside { background: var(--surface); border-right: 1px solid var(--line); padding: 22px 14px; position: sticky; top: 0; height: 100vh;
          display: flex; flex-direction: column; gap: 6px; }
  .brand { display: flex; align-items: center; gap: 10px; padding: 0 10px 18px; font-weight: 650; font-size: 16px; letter-spacing: -.01em; }
  .brand .logo { width: 34px; height: 34px; border-radius: 10px; background: var(--accent); color: #fff; display: grid; place-items: center; }
  :root[data-theme="dark"] .brand .logo { color: #0b0d12; }
  @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) .brand .logo { color: #0b0d12; } }
  .brand small { display: block; font-weight: 450; color: var(--text-3); font-size: 12px; }
  nav a { display: flex; align-items: center; gap: 10px; padding: 9px 12px; border-radius: 10px; text-decoration: none; color: var(--text-2); font-weight: 500; }
  nav a:hover { background: var(--surface-2); color: var(--text); }
  nav a.active { background: var(--accent-soft); color: var(--accent); }
  nav a .count { margin-left: auto; font-size: 12px; background: var(--surface-2); color: var(--text-2); border-radius: 999px; padding: 0 8px; }
  nav a .count.alert { background: var(--amber-soft); color: var(--amber); }
  .aside-foot { margin-top: auto; padding: 12px; font-size: 12px; color: var(--text-3); display: grid; gap: 8px; }
  .aside-foot button { all: unset; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; color: var(--text-2); }
  .theme { display: inline-flex; padding: 3px; border-radius: 10px; background: var(--surface-2); border: 1px solid var(--line); gap: 2px; }
  .theme button { all: unset; cursor: pointer; display: inline-flex; align-items: center; gap: 5px; padding: 5px 8px; border-radius: 7px; font-size: 12px; color: var(--text-2); }
  .theme button[aria-pressed="true"] { background: var(--surface); color: var(--text); box-shadow: var(--shadow); }
  .theme-mobile { display: none; }
  main { padding: 32px 40px 56px; max-width: 1180px; width: 100%; }
  .page-title { font-size: 26px; font-weight: 680; letter-spacing: -.02em; margin: 0 0 4px; }
  .lead { color: var(--text-2); margin: 0 0 28px; font-size: 16px; }
  h2.section { display: flex; align-items: center; gap: 8px; font-size: 15px; font-weight: 620; margin: 32px 0 12px; color: var(--text); }
  h2.section .hint { font-weight: 400; color: var(--text-3); font-size: 13px; }
  .card { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); box-shadow: var(--shadow); }
  .stack { display: grid; gap: 12px; }
  .grid-2 { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 14px; }
  .kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 14px; }
  .kpi { padding: 16px 18px; display: flex; gap: 14px; align-items: center; }
  .kpi .badge { width: 40px; height: 40px; border-radius: 12px; display: grid; place-items: center; }
  .kpi b { font-size: 24px; font-weight: 680; display: block; line-height: 1.1; }
  .kpi span { color: var(--text-2); font-size: 13px; }
  .tone-amber { background: var(--amber-soft); color: var(--amber); } .tone-sky { background: var(--sky-soft); color: var(--sky); }
  .tone-emerald { background: var(--emerald-soft); color: var(--emerald); } .tone-slate { background: var(--slate-soft); color: var(--slate); }
  .tone-rose { background: var(--rose-soft); color: var(--rose); } .tone-accent { background: var(--accent-soft); color: var(--accent); }
  .action { padding: 16px 18px; display: grid; grid-template-columns: auto 1fr auto; gap: 14px; align-items: center; border-left: 4px solid var(--amber); }
  .action .badge { width: 38px; height: 38px; border-radius: 11px; display: grid; place-items: center; }
  .action p { margin: 0; } .action .what { font-weight: 560; } .muted { color: var(--text-2); } .faint { color: var(--text-3); font-size: 13px; }
  .btn { display: inline-flex; align-items: center; gap: 6px; padding: 8px 12px; border-radius: 10px; border: 1px solid var(--line);
         background: var(--surface); text-decoration: none; font-weight: 520; font-size: 14px; color: var(--text); white-space: nowrap; }
  .btn:hover { border-color: var(--accent); color: var(--accent); }
  .empty { padding: 22px; text-align: center; color: var(--text-2); display: grid; justify-items: center; gap: 8px; }
  .pill { display: inline-flex; align-items: center; gap: 6px; padding: 3px 10px; border-radius: 999px; font-size: 12.5px; font-weight: 560; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .chip { font-size: 12.5px; padding: 3px 9px; border-radius: 8px; background: var(--surface-2); border: 1px solid var(--line); color: var(--text-2); }
  code, .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12.5px; }
  .feature-mini { padding: 16px 18px; display: grid; gap: 10px; text-decoration: none; }
  .feature-mini:hover { border-color: var(--accent); }
  .row { display: flex; align-items: center; gap: 10px; } .row.between { justify-content: space-between; }
  .bar { height: 6px; border-radius: 99px; background: var(--slate-soft); overflow: hidden; }
  .bar i { display: block; height: 100%; background: var(--accent); border-radius: 99px; }
  .feed { padding: 6px 0; }
  .feed-item { display: grid; grid-template-columns: 34px 1fr auto; gap: 12px; padding: 10px 18px; align-items: start; }
  .feed-item + .feed-item { border-top: 1px solid var(--line); }
  .feed-item .badge { width: 30px; height: 30px; border-radius: 9px; display: grid; place-items: center; }
  .project-card { padding: 18px; display: grid; gap: 12px; text-decoration: none; }
  .project-card:hover { border-color: var(--accent); }
  .project-card h3 { margin: 0; font-size: 17px; font-weight: 640; }
  /* Process d'une feature */
  .process { padding: 22px 20px 18px; overflow-x: auto; }
  .steps { display: flex; align-items: flex-start; min-width: 720px; }
  .step { flex: 1; display: grid; justify-items: center; text-align: center; gap: 8px; position: relative; padding: 0 4px; }
  .step::before { content: ""; position: absolute; top: 21px; left: calc(-50% + 26px); right: calc(50% + 26px); height: 2px; background: var(--line); }
  .step:first-child::before { display: none; }
  .step.s-done::before, .step.s-active::before, .step.s-waiting::before { background: var(--accent); }
  .step .dot { width: 44px; height: 44px; border-radius: 50%; display: grid; place-items: center; border: 2px solid var(--line); background: var(--surface); color: var(--text-3); z-index: 1; }
  .step.s-done .dot { background: var(--accent); border-color: var(--accent); color: #fff; }
  :root[data-theme="dark"] .step.s-done .dot { color: #0b0d12; }
  @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) .step.s-done .dot { color: #0b0d12; } }
  .step.s-active .dot { border-color: var(--sky); color: var(--sky); background: var(--sky-soft); box-shadow: 0 0 0 5px var(--sky-soft); }
  .step.s-waiting .dot { border-color: var(--amber); color: var(--amber); background: var(--amber-soft); box-shadow: 0 0 0 5px var(--amber-soft); }
  .step.s-skipped .dot { border-style: dashed; }
  .step .label { font-weight: 580; font-size: 13.5px; }
  .step .state { font-size: 12px; color: var(--text-3); }
  .step.s-active .state { color: var(--sky); } .step.s-waiting .state { color: var(--amber); font-weight: 560; } .step.s-done .state { color: var(--text-2); }
  .spin { animation: spin 1.6s linear infinite; } @keyframes spin { to { transform: rotate(360deg); } }
  .callout { margin-top: 18px; padding: 12px 14px; border-radius: 12px; display: flex; gap: 10px; align-items: flex-start; font-size: 14px; }
  .two-cols { display: grid; grid-template-columns: 1.4fr 1fr; gap: 14px; }
  .kv { display: grid; grid-template-columns: auto 1fr; gap: 6px 16px; font-size: 14px; padding: 16px 18px; }
  .kv dt { color: var(--text-3); } .kv dd { margin: 0; }
  .list { margin: 0; padding: 6px 0; list-style: none; }
  .list li { padding: 9px 18px; display: flex; gap: 10px; align-items: center; font-size: 14px; }
  .list li + li { border-top: 1px solid var(--line); }
  .back { display: inline-flex; align-items: center; gap: 6px; color: var(--text-2); text-decoration: none; font-size: 14px; margin-bottom: 14px; }
  /* Documentation */
  .doc { display: grid; grid-template-columns: 200px 1fr; gap: 28px; align-items: start; }
  .toc { position: sticky; top: 24px; display: grid; gap: 2px; font-size: 14px; }
  .toc a { text-decoration: none; color: var(--text-2); padding: 6px 10px; border-radius: 8px; }
  .toc a:hover { background: var(--surface); color: var(--text); }
  .doc section { scroll-margin-top: 20px; }
  .doc h3 { font-size: 19px; margin: 0 0 6px; letter-spacing: -.01em; }
  .doc p { margin: 0 0 12px; color: var(--text-2); }
  .doc .block { padding: 20px 22px; margin-bottom: 18px; }
  .flow { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-top: 14px; }
  .flow-step { padding: 14px; border-radius: 12px; background: var(--surface-2); border: 1px solid var(--line); display: grid; gap: 6px; font-size: 13.5px; }
  .flow-step b { display: flex; align-items: center; gap: 8px; font-size: 14px; }
  .flow-step.gate { border-color: var(--amber); background: var(--amber-soft); }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  th, td { text-align: left; padding: 10px 12px; vertical-align: top; border-top: 1px solid var(--line); }
  th { font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: var(--text-3); border-top: none; }
  td code { white-space: nowrap; color: var(--accent); }
  .steps-num { counter-reset: n; display: grid; gap: 10px; margin: 8px 0 0; padding: 0; list-style: none; }
  .steps-num li { counter-increment: n; display: grid; grid-template-columns: 28px 1fr; gap: 10px; color: var(--text-2); }
  .steps-num li::before { content: counter(n); width: 26px; height: 26px; border-radius: 50%; background: var(--accent-soft); color: var(--accent); display: grid; place-items: center; font-weight: 650; font-size: 13px; }
  .faq dt { font-weight: 580; margin-top: 12px; } .faq dd { margin: 4px 0 0; color: var(--text-2); }
  @media (max-width: 900px) {
    .app { grid-template-columns: 1fr; background: var(--bg); }
    aside { position: static; height: auto; flex-direction: row; flex-wrap: wrap; align-items: center; padding: 12px 16px; }
    .brand { padding: 0 8px 0 0; } nav { display: flex; gap: 4px; flex-wrap: wrap; } .aside-foot { display: none; }
    .theme-mobile { display: inline-flex; margin-left: auto; }
    main { padding: 22px 16px 40px; } .two-cols, .doc { grid-template-columns: 1fr; } .toc { position: static; display: none; }
    .action { grid-template-columns: auto 1fr; } .action .btn { grid-column: 1 / -1; justify-self: start; }
  }
</style>
</head>
<body>
<div class="app">
  <aside>
    <div class="brand"><span class="logo" data-icon="workflow"></span><span>Top Factory<small>Tableau de bord</small></span></div>
    <nav id="nav"></nav>
    <div class="theme theme-mobile" id="theme-m" role="group" aria-label="Thème"></div>
    <div class="aside-foot">
      <div class="theme" id="theme" role="group" aria-label="Thème"></div>
      <span id="updated"></span>
      <button id="auto" type="button"></button>
      <span id="kit"></span>
    </div>
  </aside>
  <main id="view" aria-live="polite"></main>
</div>
<script id="data" type="application/json">
TF_HTML_END
printf '%s\n' "$data"
cat <<'TF_HTML_END'
</script>
<script>
const ICONS = {"layout-dashboard": "<rect width=\"7\" height=\"9\" x=\"3\" y=\"3\" rx=\"1\" /> <rect width=\"7\" height=\"5\" x=\"14\" y=\"3\" rx=\"1\" /> <rect width=\"7\" height=\"9\" x=\"14\" y=\"12\" rx=\"1\" /> <rect width=\"7\" height=\"5\" x=\"3\" y=\"16\" rx=\"1\" />", "folder-kanban": "<path d=\"M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13c0 1.1.9 2 2 2Z\" /> <path d=\"M8 10v4\" /> <path d=\"M12 10v2\" /> <path d=\"M16 10v6\" />", "book-open": "<path d=\"M12 7v14\" /> <path d=\"M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z\" />", "git-branch": "<line x1=\"6\" x2=\"6\" y1=\"3\" y2=\"15\" /> <circle cx=\"18\" cy=\"6\" r=\"3\" /> <circle cx=\"6\" cy=\"18\" r=\"3\" /> <path d=\"M18 9a9 9 0 0 1-9 9\" />", "file-text": "<path d=\"M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z\" /> <path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /> <path d=\"M10 9H8\" /> <path d=\"M16 13H8\" /> <path d=\"M16 17H8\" />", "circle-pause": "<circle cx=\"12\" cy=\"12\" r=\"10\" /> <line x1=\"10\" x2=\"10\" y1=\"15\" y2=\"9\" /> <line x1=\"14\" x2=\"14\" y1=\"15\" y2=\"9\" />", "compass": "<path d=\"m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z\" /> <circle cx=\"12\" cy=\"12\" r=\"10\" />", "code": "<polyline points=\"16 18 22 12 16 6\" /> <polyline points=\"8 6 2 12 8 18\" />", "flask-conical": "<path d=\"M10 2v7.527a2 2 0 0 1-.211.896L4.72 20.55a1 1 0 0 0 .9 1.45h12.76a1 1 0 0 0 .9-1.45l-5.069-10.127A2 2 0 0 1 14 9.527V2\" /> <path d=\"M8.5 2h7\" /> <path d=\"M7 16h10\" />", "search-check": "<path d=\"m8 11 2 2 4-4\" /> <circle cx=\"11\" cy=\"11\" r=\"8\" /> <path d=\"m21 21-4.3-4.3\" />", "git-commit-horizontal": "<circle cx=\"12\" cy=\"12\" r=\"3\" /> <line x1=\"3\" x2=\"9\" y1=\"12\" y2=\"12\" /> <line x1=\"15\" x2=\"21\" y1=\"12\" y2=\"12\" />", "git-pull-request": "<circle cx=\"18\" cy=\"18\" r=\"3\" /> <circle cx=\"6\" cy=\"6\" r=\"3\" /> <path d=\"M13 6h3a2 2 0 0 1 2 2v7\" /> <line x1=\"6\" x2=\"6\" y1=\"9\" y2=\"21\" />", "bug": "<path d=\"m8 2 1.88 1.88\" /> <path d=\"M14.12 3.88 16 2\" /> <path d=\"M9 7.13v-1a3.003 3.003 0 1 1 6 0v1\" /> <path d=\"M12 20c-3.3 0-6-2.7-6-6v-3a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v3c0 3.3-2.7 6-6 6\" /> <path d=\"M12 20v-9\" /> <path d=\"M6.53 9C4.6 8.8 3 7.1 3 5\" /> <path d=\"M6 13H2\" /> <path d=\"M3 21c0-2.1 1.7-3.9 3.8-4\" /> <path d=\"M20.97 5c0 2.1-1.6 3.8-3.5 4\" /> <path d=\"M22 13h-4\" /> <path d=\"M17.2 17c2.1.1 3.8 1.9 3.8 4\" />", "hammer": "<path d=\"m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9\" /> <path d=\"m18 15 4-4\" /> <path d=\"m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18.5 14.5\" />", "circle-check-big": "<path d=\"M21.801 10A10 10 0 1 1 17 3.335\" /> <path d=\"m9 11 3 3L22 4\" />", "loader-circle": "<path d=\"M21 12a9 9 0 1 1-6.219-8.56\" />", "lock-keyhole": "<circle cx=\"12\" cy=\"16\" r=\"1\" /> <rect x=\"3\" y=\"10\" width=\"18\" height=\"12\" rx=\"2\" /> <path d=\"M7 10V7a5 5 0 0 1 10 0v3\" />", "message-circle-question": "<path d=\"M7.9 20A9 9 0 1 0 4 16.1L2 22Z\" /> <path d=\"M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3\" /> <path d=\"M12 17h.01\" />", "bot": "<path d=\"M12 8V4H8\" /> <rect width=\"16\" height=\"12\" x=\"4\" y=\"8\" rx=\"2\" /> <path d=\"M2 14h2\" /> <path d=\"M20 14h2\" /> <path d=\"M15 13v2\" /> <path d=\"M9 13v2\" />", "play": "<polygon points=\"6 3 20 12 6 21 6 3\" />", "square": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" />", "moon-star": "<path d=\"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9\" /> <path d=\"M20 3v4\" /> <path d=\"M22 5h-4\" />", "triangle-alert": "<path d=\"m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3\" /> <path d=\"M12 9v4\" /> <path d=\"M12 17h.01\" />", "bell": "<path d=\"M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9\" /> <path d=\"M10.3 21a1.94 1.94 0 0 0 3.4 0\" />", "sparkles": "<path d=\"M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z\" /> <path d=\"M20 3v4\" /> <path d=\"M22 5h-4\" /> <path d=\"M4 17v2\" /> <path d=\"M5 18H3\" />", "history": "<path d=\"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8\" /> <path d=\"M3 3v5h5\" /> <path d=\"M12 7v5l4 2\" />", "list-checks": "<path d=\"m3 17 2 2 4-4\" /> <path d=\"m3 7 2 2 4-4\" /> <path d=\"M13 6h8\" /> <path d=\"M13 12h8\" /> <path d=\"M13 18h8\" />", "terminal": "<polyline points=\"4 17 10 11 4 5\" /> <line x1=\"12\" x2=\"20\" y1=\"19\" y2=\"19\" />", "users-round": "<path d=\"M18 21a8 8 0 0 0-16 0\" /> <circle cx=\"10\" cy=\"8\" r=\"5\" /> <path d=\"M22 20c0-3.37-2-6.5-4-8a5 5 0 0 0-.45-8.3\" />", "layers": "<path d=\"m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z\" /> <path d=\"m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65\" /> <path d=\"m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65\" />", "settings-2": "<path d=\"M20 7h-9\" /> <path d=\"M14 17H5\" /> <circle cx=\"17\" cy=\"17\" r=\"3\" /> <circle cx=\"7\" cy=\"7\" r=\"3\" />", "shield-check": "<path d=\"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z\" /> <path d=\"m9 12 2 2 4-4\" />", "cloud-upload": "<path d=\"M12 13v8\" /> <path d=\"M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242\" /> <path d=\"m8 17 4-4 4 4\" />", "clock": "<circle cx=\"12\" cy=\"12\" r=\"10\" /> <polyline points=\"12 6 12 12 16 14\" />", "check": "<path d=\"M20 6 9 17l-5-5\" />", "life-buoy": "<circle cx=\"12\" cy=\"12\" r=\"10\" /> <path d=\"m4.93 4.93 4.24 4.24\" /> <path d=\"m14.83 9.17 4.24-4.24\" /> <path d=\"m14.83 14.83 4.24 4.24\" /> <path d=\"m9.17 14.83-4.24 4.24\" /> <circle cx=\"12\" cy=\"12\" r=\"4\" />", "workflow": "<rect width=\"8\" height=\"8\" x=\"3\" y=\"3\" rx=\"2\" /> <path d=\"M7 11v4a2 2 0 0 0 2 2h4\" /> <rect width=\"8\" height=\"8\" x=\"13\" y=\"13\" rx=\"2\" />", "hand": "<path d=\"M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2\" /> <path d=\"M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2\" /> <path d=\"M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8\" /> <path d=\"M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15\" />", "server": "<rect width=\"20\" height=\"8\" x=\"2\" y=\"2\" rx=\"2\" ry=\"2\" /> <rect width=\"20\" height=\"8\" x=\"2\" y=\"14\" rx=\"2\" ry=\"2\" /> <line x1=\"6\" x2=\"6.01\" y1=\"6\" y2=\"6\" /> <line x1=\"6\" x2=\"6.01\" y1=\"18\" y2=\"18\" />", "monitor-smartphone": "<path d=\"M18 8V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h8\" /> <path d=\"M10 19v-3.96 3.15\" /> <path d=\"M7 19h5\" /> <rect width=\"6\" height=\"10\" x=\"16\" y=\"12\" rx=\"2\" />", "arrow-right": "<path d=\"M5 12h14\" /> <path d=\"m12 5 7 7-7 7\" />", "folder": "<path d=\"M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z\" />", "rocket": "<path d=\"M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z\" /> <path d=\"m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z\" /> <path d=\"M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0\" /> <path d=\"M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5\" />", "plug": "<path d=\"M12 22v-5\" /> <path d=\"M9 8V2\" /> <path d=\"M15 8V2\" /> <path d=\"M18 8v5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8Z\" />", "palette": "<circle cx=\"13.5\" cy=\"6.5\" r=\".5\" fill=\"currentColor\" /> <circle cx=\"17.5\" cy=\"10.5\" r=\".5\" fill=\"currentColor\" /> <circle cx=\"8.5\" cy=\"7.5\" r=\".5\" fill=\"currentColor\" /> <circle cx=\"6.5\" cy=\"12.5\" r=\".5\" fill=\"currentColor\" /> <path d=\"M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z\" />", "circle": "<circle cx=\"12\" cy=\"12\" r=\"10\" />", "info": "<circle cx=\"12\" cy=\"12\" r=\"10\" /> <path d=\"M12 16v-4\" /> <path d=\"M12 8h.01\" />", "file-search": "<path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /> <path d=\"M4.268 21a2 2 0 0 0 1.727 1H18a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v3\" /> <path d=\"m9 18-1.5-1.5\" /> <circle cx=\"5\" cy=\"14\" r=\"3\" />", "sun": "<circle cx=\"12\" cy=\"12\" r=\"4\" /> <path d=\"M12 2v2\" /> <path d=\"M12 20v2\" /> <path d=\"m4.93 4.93 1.41 1.41\" /> <path d=\"m17.66 17.66 1.41 1.41\" /> <path d=\"M2 12h2\" /> <path d=\"M20 12h2\" /> <path d=\"m6.34 17.66-1.41 1.41\" /> <path d=\"m19.07 4.93-1.41 1.41\" />", "moon": "<path d=\"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z\" />"};
(function () {
  'use strict';
  const D = JSON.parse(document.getElementById('data').textContent);
  const P = D.prefix || '/top-factory:';
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const icon = (name, cls) => `<svg class="icon ${cls || ''}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ICONS.circle}</svg>`;
  const ago = iso => {
    if (!iso) return '';
    const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
    if (s < 45) return 'à l\'instant';
    if (s < 3600) return 'il y a ' + Math.round(s / 60) + ' min';
    if (s < 86400) return 'il y a ' + Math.round(s / 3600) + ' h';
    const d = Math.round(s / 86400); return d === 1 ? 'hier' : 'il y a ' + d + ' jours';
  };
  const fmt = iso => iso ? new Date(iso).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '';
  const AGENTS = { 'spec-writer': 'la rédactrice de specs', architect: 'l\'architecte', 'backend-dev': 'le développeur backend',
    'frontend-dev': 'le développeur frontend', 'test-writer': 'l\'auteur des tests', reviewer: 'le relecteur' };
  const agentName = a => (a || '').replace(/^.*:/, '');

  // ---------- Process d'une feature ----------
  const FEATURE = [
    { id: 'branch', label: 'Branche', icon: 'git-branch', help: 'Une branche dédiée, partie de la branche d\'intégration à jour.' },
    { id: 'spec', label: 'Spec', icon: 'file-text', agents: ['spec-writer'], gate: 'valider la spec', ask: 'valides la spec', help: 'Le besoin reformulé : règles, cas limites, questions ouvertes.' },
    { id: 'plan', label: 'Plan technique', icon: 'compass', agents: ['architect'], gate: 'valider le plan technique', ask: 'valides le plan technique', help: 'Couches, classes, migrations, contrat d\'API.' },
    { id: 'code', label: 'Code', icon: 'code', agents: ['backend-dev', 'frontend-dev'], back: true, help: 'Implémentation backend puis frontend, contrôlée par les garde-fous.' },
    { id: 'tests', label: 'Tests', icon: 'flask-conical', agents: ['test-writer'], help: 'Tests par couche, intégration avec Testcontainers, ArchUnit.' },
    { id: 'review', label: 'Revue', icon: 'search-check', agents: ['reviewer'], gate: 'décider de la suite à partir du verdict de la revue', ask: 'décides de la suite à partir du verdict de la revue', help: 'Architecture, sécurité, qualité, tests.' },
    { id: 'commit', label: 'Commit', icon: 'git-commit-horizontal', event: 'commit', help: 'Commit au format Conventional Commits, après ton accord.' },
    { id: 'pr', label: 'Pull Request', icon: 'git-pull-request', event: 'push', help: 'Branche poussée ; tu ouvres la PR et tu fusionnes.' },
  ];
  const FIX = [
    { id: 'branch', label: 'Branche', icon: 'git-branch' },
    { id: 'repro', label: 'Reproduire', icon: 'bug', agents: ['test-writer'], help: 'Un test qui échoue prouve le bug.' },
    { id: 'code', label: 'Corriger', icon: 'hammer', agents: ['backend-dev', 'frontend-dev'], back: true, help: 'Correction minimale de la cause racine.' },
    { id: 'review', label: 'Revue', icon: 'search-check', agents: ['reviewer'], gate: 'décider de la suite à partir du verdict de la revue', ask: 'décides de la suite à partir du verdict de la revue' },
    { id: 'commit', label: 'Commit', icon: 'git-commit-horizontal', event: 'commit' },
    { id: 'pr', label: 'Pull Request', icon: 'git-pull-request', event: 'push' },
  ];
  const STATE_TEXT = { done: 'Terminé', active: 'En cours', waiting: 'Ta validation', todo: 'À venir', skipped: 'Non utilisée' };

  function buildProcess(branch, events) {
    const model = /^(fix|bugfix|hotfix)\//.test(branch) ? FIX : FEATURE;
    const st = model.map(() => 'todo');
    const running = {};
    let cur = -1, lastTs = null;
    const idxAgent = a => model.findIndex(s => (s.agents || []).includes(agentName(a)));
    const idxEvent = k => model.findIndex(s => s.event === k);
    const reach = i => {
      for (let k = 1; k < i; k++) if (st[k] === 'todo') st[k] = 'skipped';
      for (let k = 0; k < i; k++) if (st[k] === 'active' || st[k] === 'waiting') st[k] = 'done';
      cur = Math.max(cur, i);
    };
    events.forEach((e, n) => {
      lastTs = e.ts;
      if (n === 0) { st[0] = 'done'; cur = 0; }
      const ag = agentName(e.agent || (e.title || '').replace(/^Agent (\S+).*$/, '$1'));
      if (e.kind === 'agent_start') {
        const i = idxAgent(ag); if (i < 0) return;
        running[i] = (running[i] || 0) + 1;
        if (i < cur && model[i].back) { for (let k = i + 1; k < model.length; k++) if (st[k] !== 'skipped') st[k] = 'todo'; cur = i; }
        else if (i < cur) return;
        reach(i); st[i] = 'active';
      } else if (e.kind === 'agent_end') {
        const i = idxAgent(ag); if (i < 0) return;
        running[i] = Math.max(0, (running[i] || 1) - 1);
        if (!running[i] && st[i] === 'active') st[i] = 'done';
      } else if (e.kind === 'validation') {
        let i = cur; while (i > 0 && !model[i].gate && st[i] !== 'active') i--;
        if (i > 0 && model[i].gate && (st[i] === 'done' || st[i] === 'active')) st[i] = 'waiting';
      } else if (e.kind === 'prompt') {
        // Tu as répondu : la validation attendue est donnée.
        for (let k = 0; k < st.length; k++) if (st[k] === 'waiting') st[k] = 'done';
      } else if (e.kind === 'commit' || e.kind === 'push') {
        const i = idxEvent(e.kind); if (i < 0) return;
        reach(i); st[i] = 'done';
      }
    });
    const counted = st.filter(s => s !== 'skipped').length;
    const done = st.filter(s => s === 'done').length;
    const curStep = model[Math.max(0, st.findIndex(s => s === 'waiting') >= 0 ? st.findIndex(s => s === 'waiting') : (st.lastIndexOf('active') >= 0 ? st.lastIndexOf('active') : cur))];
    return { model, st, done, total: counted, pct: counted ? Math.round(done * 100 / counted) : 0, current: curStep,
             waiting: st.indexOf('waiting'), lastTs, kind: model === FIX ? 'Correction' : 'Feature' };
  }

  // ---------- État d'un projet ----------
  const STATES = {
    validation: { tone: 'amber', icon: 'circle-pause', label: 'Attend ta validation', todo: true },
    permission: { tone: 'amber', icon: 'lock-keyhole', label: 'Attend ton autorisation', todo: true },
    attention: { tone: 'amber', icon: 'message-circle-question', label: 'Attend ta réponse', todo: true },
    turn_end: { tone: 'emerald', icon: 'hand', label: 'À toi de jouer', todo: true },
    agent_start: { tone: 'sky', icon: 'bot', label: 'Un agent travaille', work: true },
    prompt: { tone: 'sky', icon: 'loader-circle', label: 'Claude travaille', work: true },
    agent_end: { tone: 'sky', icon: 'bot', label: 'Claude enchaîne', work: true },
    session_start: { tone: 'sky', icon: 'play', label: 'Session ouverte' },
    commit: { tone: 'emerald', icon: 'git-commit-horizontal', label: 'Commit effectué' },
    push: { tone: 'emerald', icon: 'cloud-upload', label: 'Branche poussée' },
    session_end: { tone: 'slate', icon: 'square', label: 'Session fermée' },
    idle: { tone: 'slate', icon: 'moon-star', label: 'Au repos' },
    missing: { tone: 'rose', icon: 'triangle-alert', label: 'Dossier introuvable' },
  };
  const EVENT_ICON = { prompt: 'message-circle-question', session_start: 'play', session_end: 'square', agent_start: 'bot', agent_end: 'circle-check-big', validation: 'circle-pause',
    permission: 'lock-keyhole', attention: 'message-circle-question', turn_end: 'hand', commit: 'git-commit-horizontal', push: 'cloud-upload' };
  const EVENT_TONE = { validation: 'amber', permission: 'amber', attention: 'amber', turn_end: 'emerald', commit: 'emerald', push: 'emerald',
    agent_start: 'sky', agent_end: 'sky', session_start: 'slate', session_end: 'slate' };

  function analyse(p) {
    const ev = p.events || [];
    const last = ev[ev.length - 1];
    let key = 'idle';
    if (!p.exists) key = 'missing';
    else if (last && Date.now() - new Date(last.ts).getTime() < 86400000) {
      key = STATES[last.kind] ? last.kind : 'idle';
      // Agents encore au travail depuis l'ouverture de la session : Claude n'a pas vraiment rendu la main.
      let open = 0;
      ev.slice(-80).forEach(e => { if (e.kind === 'session_start') open = 0; if (e.kind === 'agent_start') open++; if (e.kind === 'agent_end') open = Math.max(0, open - 1); });
      if (open && ['agent_end', 'turn_end', 'prompt', 'session_start'].includes(key)) key = 'agent_start';
    }
    const base = p.baseBranch || 'develop';
    const byBranch = {};
    ev.forEach(e => { const b = e.branch || ''; if (!b || b === base || b === 'main' || b === 'master' || b === 'HEAD') return; (byBranch[b] = byBranch[b] || []).push(e); });
    const features = Object.entries(byBranch).map(([b, list]) => ({ branch: b, name: b.replace(/^[^/]+\//, '').replace(/[-_]/g, ' '), ...buildProcess(b, list) }))
      .sort((a, b) => (b.lastTs || '').localeCompare(a.lastTs || ''));
    const current = features.find(f => f.branch === p.branch) || null;
    return { ...p, key, state: STATES[key], last, features, current };
  }
  const projects = (D.projects || []).map(analyse).sort((a, b) => ((b.last || {}).ts || '').localeCompare((a.last || {}).ts || ''));
  const todo = projects.filter(p => p.state.todo);
  const working = projects.filter(p => p.state.work);

  function sentence(p) {
    const f = p.current, e = p.last || {};
    const what = f ? `<b>${esc(f.name)}</b>` : (e.branch ? `la branche <code>${esc(e.branch)}</code>` : 'le projet');
    switch (p.key) {
      case 'validation': {
        const g = f && f.waiting >= 0 ? f.model[f.waiting].ask : null;
        return g ? `Claude attend que tu ${esc(g)} de ${what}.` : `Claude attend ta validation pour continuer ${what}.`;
      }
      case 'permission': return `Claude a besoin de ton autorisation pour continuer ${what}.`;
      case 'attention': return `Claude t'a posé une question sur ${what}.`;
      case 'turn_end': return `Claude a terminé ce que tu lui as demandé sur ${what} et te rend la main.`;
      default: return '';
    }
  }

  // ---------- Rendu ----------
  const badge = (name, tone, size) => `<span class="badge tone-${tone}">${icon(name, size)}</span>`;
  const pill = (st) => `<span class="pill tone-${st.tone}">${icon(st.icon, 'sm')}${esc(st.label)}</span>`;
  function stepper(f) {
    return `<div class="steps">${f.model.map((s, i) => {
      const k = f.st[i];
      const ic = k === 'done' ? 'check' : k === 'waiting' ? 'circle-pause' : k === 'active' ? 'loader-circle' : s.icon;
      return `<div class="step s-${k}" title="${esc(s.help || '')}"><span class="dot">${icon(ic, (k === 'active' ? 'spin ' : '') + 'lg')}</span>
        <span class="label">${esc(s.label)}</span><span class="state">${STATE_TEXT[k]}</span></div>`;
    }).join('')}</div>`;
  }
  function feedItem(e, p) {
    const tone = EVENT_TONE[e.kind] || 'slate';
    return `<div class="feed-item">${badge(EVENT_ICON[e.kind] || 'circle', tone, 'sm')}
      <div><div>${p ? `<b>${esc(p.name)}</b> · ` : ''}${esc((e.title || '').replace(/Agent [\w-]+:/, 'Agent '))}</div>${e.detail ? `<div class="faint">${esc(e.detail)}</div>` : ''}
      ${e.branch ? `<div class="faint">${icon('git-branch', 'sm')} <span class="mono">${esc(e.branch)}</span></div>` : ''}</div>
      <span class="faint" title="${esc(fmt(e.ts))}">${ago(e.ts)}</span></div>`;
  }
  function emptyBox(ic, title, text) { return `<div class="card empty">${badge(ic, 'slate', 'lg')}<b>${esc(title)}</b><span>${text}</span></div>`; }

  function viewOverview() {
    const h = new Date().getHours();
    const hello = (h < 5 || h >= 18 ? 'Bonsoir' : 'Bonjour') + (D.user ? ' ' + esc(D.user) : '');
    const sum = projects.length === 0 ? 'Aucun projet suivi pour l\'instant.'
      : todo.length ? `${todo.length === 1 ? 'Un projet attend' : todo.length + ' projets attendent'} une action de ta part.`
      : working.length ? 'Les agents travaillent, rien ne t\'attend pour le moment.' : 'Tout est calme : rien ne t\'attend.';
    const feats = projects.flatMap(p => p.features.slice(0, 3).map(f => ({ p, f }))).sort((a, b) => (b.f.lastTs || '').localeCompare(a.f.lastTs || '')).slice(0, 6);
    const feed = projects.flatMap(p => (p.events || []).filter(e => e.kind !== 'prompt').map(e => ({ e, p }))).sort((a, b) => b.e.ts.localeCompare(a.e.ts)).slice(0, 8);
    return `<h1 class="page-title">${hello} 👋</h1><p class="lead">${sum}</p>
    <div class="kpis">
      <div class="card kpi">${badge('folder-kanban', 'accent')}<div><b>${projects.length}</b><span>projet${projects.length > 1 ? 's' : ''} suivi${projects.length > 1 ? 's' : ''}</span></div></div>
      <div class="card kpi">${badge('bell', 'amber')}<div><b>${todo.length}</b><span>en attente de toi</span></div></div>
      <div class="card kpi">${badge('bot', 'sky')}<div><b>${working.length}</b><span>agent${working.length > 1 ? 's' : ''} au travail</span></div></div>
      <div class="card kpi">${badge('list-checks', 'emerald')}<div><b>${feats.length}</b><span>feature${feats.length > 1 ? 's' : ''} en cours</span></div></div>
    </div>
    <h2 class="section">${icon('bell')} Ça t'attend</h2>
    <div class="stack">${todo.length ? todo.map(p => `<div class="card action">${badge(p.state.icon, p.state.tone)}
        <div><p class="what">${esc(p.name)} — ${esc(p.state.label)}</p><p class="muted">${sentence(p)}</p>
        ${p.last && p.last.detail ? `<p class="faint">« ${esc(p.last.detail)} »</p>` : ''}<p class="faint">${ago((p.last || {}).ts)}</p></div>
        <a class="btn" href="#/projet/${encodeURIComponent(p.id)}">Voir le projet ${icon('arrow-right', 'sm')}</a></div>`).join('')
      : emptyBox('sparkles', 'Rien à faire pour toi', 'Tu seras prévenu dès qu\'une validation ou une autorisation sera nécessaire.')}</div>
    <h2 class="section">${icon('workflow')} Features en cours</h2>
    ${feats.length ? `<div class="grid-2">${feats.map(({ p, f }) => `<a class="card feature-mini" href="#/projet/${encodeURIComponent(p.id)}">
        <div class="row between"><b>${esc(f.name)}</b><span class="faint">${esc(p.name)}</span></div>
        <div class="bar"><i style="width:${f.pct}%"></i></div>
        <div class="row between faint"><span>${f.waiting >= 0 ? `<span style="color:var(--amber)">${icon('circle-pause', 'sm')} ${esc(f.model[f.waiting].label)} : ta validation</span>` : `Étape : ${esc(f.current.label)}`}</span><span>${f.done}/${f.total}</span></div></a>`).join('')}</div>`
      : emptyBox('workflow', 'Aucune feature en cours', `Lance <code>${esc(P)}feature</code> dans un projet : son avancement apparaîtra ici.`)}
    <h2 class="section">${icon('history')} Activité récente</h2>
    ${feed.length ? `<div class="card feed">${feed.map(x => feedItem(x.e, x.p)).join('')}</div>` : emptyBox('history', 'Pas encore d\'activité', 'Ouvre Claude dans un projet initialisé avec la factory.')}`;
  }

  function viewProjects() {
    return `<h1 class="page-title">Projets</h1><p class="lead">Chaque projet initialisé avec la factory apparaît ici dès que Claude y est ouvert.</p>
    ${projects.length ? `<div class="grid-2">${projects.map(p => `<a class="card project-card" href="#/projet/${encodeURIComponent(p.id)}">
      <div class="row between"><h3>${esc(p.name)}</h3>${pill(p.state)}</div>
      <div class="faint mono">${esc(p.path)}</div>
      ${p.current ? `<div><div class="row between faint"><span>${icon('workflow', 'sm')} ${esc(p.current.name)}</span><span>${p.current.done}/${p.current.total}</span></div><div class="bar" style="margin-top:6px"><i style="width:${p.current.pct}%"></i></div></div>` : ''}
      <div class="chips"><span class="chip">${esc(p.architecture || '—')}</span><span class="chip">backend : ${esc(p.backend || '—')}</span>
        <span class="chip">frontend : ${esc(p.frontend == null ? 'aucun' : p.frontend)}</span>${p.branch ? `<span class="chip mono">${esc(p.branch)}</span>` : ''}</div>
      <div class="faint">${p.last ? 'Dernière activité ' + ago(p.last.ts) : 'Aucune activité'}</div></a>`).join('')}</div>`
      : emptyBox('folder', 'Aucun projet', 'Ouvre Claude dans un projet initialisé avec la factory : il apparaîtra ici.')}`;
  }

  function viewProject(id) {
    const p = projects.find(x => x.id === id);
    if (!p) return `<a class="back" href="#/projets">${icon('arrow-right')} Projets</a>${emptyBox('triangle-alert', 'Projet introuvable', '')}`;
    const f = p.current || p.features[0];
    const lc = (p.lastCommit || '').split('|');
    let callout = '';
    if (f && f.waiting >= 0) callout = `<div class="callout tone-amber">${icon('circle-pause')}<div><b>À toi : ${esc(f.model[f.waiting].gate)}.</b><br>Lis la proposition de Claude dans ta session, puis réponds pour qu'il continue.</div></div>`;
    else if (p.key === 'permission') callout = `<div class="callout tone-amber">${icon('lock-keyhole')}<div><b>Claude attend ton autorisation.</b><br>${esc((p.last || {}).detail || '')}</div></div>`;
    else if (f && f.st.includes('active')) callout = `<div class="callout tone-sky">${icon('bot')}<div><b>${esc(f.current.label)} en cours.</b> ${esc(f.current.help || '')}</div></div>`;
    const others = p.features.filter(x => x !== f);
    return `<a class="back" href="#/projets">${icon('folder-kanban', 'sm')} Projets</a>
    <div class="row between" style="flex-wrap:wrap"><h1 class="page-title">${esc(p.name)}</h1>${pill(p.state)}</div>
    <p class="lead mono" style="font-size:13px">${esc(p.path)}</p>
    <h2 class="section">${icon('workflow')} ${f ? esc(f.kind) + ' : ' + esc(f.name) : 'Process'} ${f ? `<span class="hint">· ${f.done}/${f.total} étapes · <span class="mono">${esc(f.branch)}</span></span>` : ''}</h2>
    ${f ? `<div class="card process">${stepper(f)}${callout}</div>`
      : emptyBox('workflow', 'Aucune feature en cours', `Le process s'affiche dès que tu travailles sur une branche de feature avec <code>${esc(P)}feature</code>.`)}
    <div class="two-cols" style="margin-top:14px">
      <div><h2 class="section">${icon('history')} Activité</h2>
        ${(p.events || []).length ? `<div class="card feed">${(p.events || []).filter(e => e.kind !== 'prompt').slice(-25).reverse().map(e => feedItem(e)).join('')}</div>` : emptyBox('history', 'Pas encore d\'activité', '')}</div>
      <div><h2 class="section">${icon('info')} Projet</h2>
        <dl class="card kv"><dt>Branche</dt><dd>${p.branch ? `<span class="mono">${esc(p.branch)}</span>` : '—'}</dd>
          <dt>Dernier commit</dt><dd>${lc[0] ? esc(lc[0]) + `<div class="faint">${fmt(lc[1])}</div>` : '—'}</dd>
          <dt>Architecture</dt><dd>${esc(p.architecture || '—')}</dd><dt>Backend</dt><dd class="mono">${esc(p.backend || '—')}</dd>
          <dt>Frontend</dt><dd class="mono">${esc(p.frontend == null ? 'aucun' : p.frontend)}</dd><dt>Kit</dt><dd>${p.kit ? 'v' + esc(p.kit) : '—'}</dd></dl>
        <h2 class="section">${icon('file-text')} Specs et plans</h2>
        ${(p.specs || []).length ? `<ul class="card list">${p.specs.map(s => `<li>${icon('file-text', 'sm')}<span>${esc(s.name)}</span><span class="faint" style="margin-left:auto">${fmt(new Date(s.mtime * 1000).toISOString())}</span></li>`).join('')}</ul>` : emptyBox('file-search', 'Aucune spec', 'Les specs et plans de <code>docs/specs</code> apparaîtront ici.')}
        ${others.length ? `<h2 class="section">${icon('git-branch')} Autres branches</h2><ul class="card list">${others.map(o => `<li>${icon('git-branch', 'sm')}<span>${esc(o.name)}</span><span class="faint" style="margin-left:auto">${o.done}/${o.total} · ${ago(o.lastTs)}</span></li>`).join('')}</ul>` : ''}
      </div></div>`;
  }

  function viewDocs() {
    const cmd = (D.docs.commands || []);
    const ag = (D.docs.agents || []);
    const flow = [
      ['lightbulb', 'file-text', 'Spec', 'L\'agent spec-writer reformule ton besoin : règles, cas limites, questions.', true],
      ['', 'compass', 'Plan', 'L\'architecte conçoit la solution selon l\'architecture du projet.', true],
      ['', 'code', 'Code', 'Les développeurs backend et frontend implémentent, contrôlés en continu par les garde-fous.', false],
      ['', 'flask-conical', 'Tests', 'Tests de chaque couche, intégration avec de vraies dépendances, règles d\'architecture.', false],
      ['', 'search-check', 'Revue', 'Le relecteur vérifie architecture, sécurité et qualité ; tu lis le verdict.', true],
      ['', 'git-pull-request', 'Commit et PR', 'Après ton accord : commit, branche poussée ; tu ouvres la PR et tu fusionnes.', false],
    ];
    return `<h1 class="page-title">Documentation</h1><p class="lead">Comment fonctionne la Top Factory, et tout ce que tu peux lui demander.</p>
    <div class="doc"><nav class="toc">
      <a href="#/docs" data-anchor="d-principe">Le principe</a><a href="#/docs" data-anchor="d-workflow">Le workflow</a>
      <a href="#/docs" data-anchor="d-demarrer">Démarrer un projet</a><a href="#/docs" data-anchor="d-commandes">Commandes</a>
      <a href="#/docs" data-anchor="d-agents">Agents</a><a href="#/docs" data-anchor="d-gardefous">Garde-fous</a>
      <a href="#/docs" data-anchor="d-fichiers">Fichiers du projet</a><a href="#/docs" data-anchor="d-notifs">Notifications</a>
      <a href="#/docs" data-anchor="d-depannage">Dépannage</a></nav>
    <div>
      <section id="d-principe" class="card block"><h3>Le principe</h3>
        <p>La factory est un <b>plugin de Claude Code</b>. Elle transforme une demande en fonctionnalité livrée, en suivant toujours le même chemin :
        une spec, un plan, le code, les tests, une revue, puis un commit. Des <b>agents spécialisés</b> font chaque étape ; toi, tu valides aux moments clés.</p>
        <p>Elle respecte l'architecture choisie pour le projet (hexagonale ou en couches), tes conventions (profil, options) et tes intégrations
        (PostgreSQL, Redis…). Des <b>garde-fous</b> contrôlent chaque fichier écrit : une violation est corrigée tout de suite, pas découverte en revue.</p>
        <div class="chips"><span class="chip">Kit v${esc(D.kit || '?')}</span><span class="chip">Commandes : <code>${esc(P)}…</code></span></div></section>
      <section id="d-workflow" class="card block"><h3>Le workflow d'une feature</h3>
        <p>Lancé par <code>${esc(P)}feature &lt;besoin&gt;</code>. Les étapes en orange s'arrêtent pour ta validation : rien ne continue sans ton accord.</p>
        <div class="flow">${flow.map(f => `<div class="flow-step ${f[4] ? 'gate' : ''}"><b>${icon(f[1])} ${esc(f[2])}</b><span>${esc(f[3])}</span>${f[4] ? `<span class="faint" style="color:var(--amber)">${icon('circle-pause', 'sm')} ta validation</span>` : ''}</div>`).join('')}</div></section>
      <section id="d-demarrer" class="card block"><h3>Démarrer un projet</h3>
        <ol class="steps-num">
          <li><span>Une fois par poste, dans Claude Code : <code>/plugin marketplace add babatop2313/top-factory</code> puis <code>/plugin install top-factory@top</code>.</span></li>
          <li><span>Crée le dépôt Git et le backend Spring Boot (start.spring.io), dans le dossier de ton choix.</span></li>
          <li><span>Dans Claude, à la racine du projet : <code>${esc(P)}init</code> — architecture, branche d'intégration, intégrations, dossiers.</span></li>
          <li><span>Relance Claude, complète <code>CLAUDE.md</code>, puis <code>${esc(P)}init-architecture &lt;module&gt;</code>.</span></li>
          <li><span>Si besoin, le frontend : <code>${esc(P)}add-frontend</code>. Ensuite, chaque besoin passe par <code>${esc(P)}feature</code>.</span></li>
        </ol></section>
      <section id="d-commandes" class="card block"><h3>Commandes</h3><p>Lues directement dans le kit installé : cette liste est toujours à jour.</p>
        <table><thead><tr><th>Commande</th><th>À quoi elle sert</th></tr></thead><tbody>
        ${cmd.map(c => `<tr><td><code>${esc(P + c.name)}</code>${c.hint ? `<div class="faint mono">${esc(c.hint)}</div>` : ''}</td><td>${esc(c.description)}</td></tr>`).join('')}
        </tbody></table></section>
      <section id="d-agents" class="card block"><h3>Agents</h3><p>Chaque agent a un rôle précis et ne reçoit que les outils dont il a besoin.</p>
        <table><thead><tr><th>Agent</th><th>Rôle</th></tr></thead><tbody>
        ${ag.map(a => `<tr><td><b>${esc(a.name)}</b><div class="faint">${esc(AGENTS[a.name] || '')}</div></td><td>${esc(a.description)}</td></tr>`).join('')}
        </tbody></table></section>
      <section id="d-gardefous" class="card block"><h3>Garde-fous</h3>
        <p>Ils s'exécutent tout seuls, à chaque action de Claude. Un blocage est expliqué à Claude, qui corrige dans la foulée.</p>
        <table><tbody>
          <tr><td>${icon('layers')}</td><td><b>Architecture</b> — chaque fichier Java respecte les règles de dépendance de l'architecture et des intégrations ; <code>ArchitectureTest</code> le vérifie aussi dans les tests.</td></tr>
          <tr><td>${icon('monitor-smartphone')}</td><td><b>Frontend</b> — pas d'accès HTTP dans un composant, pas d'import entre features, jamais de jeton dans <code>localStorage</code>, pas d'URL d'API en dur.</td></tr>
          <tr><td>${icon('terminal')}</td><td><b>Compilation et types</b> — le backend est compilé et les types TypeScript vérifiés après chaque modification.</td></tr>
          <tr><td>${icon('shield-check')}</td><td><b>Commandes</b> — pas de push sur <code>main</code> ou <code>develop</code>, pas de fusion par Claude, pas de suppression de <code>.claude/</code>, pas de secret dans le code.</td></tr>
          <tr><td>${icon('server')}</td><td><b>Base de données</b> — le serveur MCP PostgreSQL est en lecture seule, avec trois lignes de défense.</td></tr>
        </tbody></table></section>
      <section id="d-fichiers" class="card block"><h3>Fichiers du projet</h3><table><tbody>
          <tr><td><code>.claude/factory.json</code></td><td>Architecture, branche d'intégration, dossiers backend et frontend. <b>Verrouillé</b> : écrit par <code>${esc(P)}init</code>, jamais modifié par Claude.</td></tr>
          <tr><td><code>.claude/stack.json</code></td><td>Profil, options de conventions (mapping, erreurs, transport du JWT, bibliothèque d'interface…) et intégrations actives.</td></tr>
          <tr><td><code>.claude/settings.json</code></td><td>Permissions partagées et activation du plugin (réécrit par le script de la factory).</td></tr>
          <tr><td><code>.claude/settings.local.json</code></td><td>Tes autorisations personnelles ; jamais commité.</td></tr>
          <tr><td><code>CLAUDE.md</code></td><td>Contexte métier, règles et commandes du projet : à compléter par toi.</td></tr>
          <tr><td><code>docs/specs/</code></td><td>Une spec et un plan par fonctionnalité.</td></tr>
        </tbody></table></section>
      <section id="d-notifs" class="card block"><h3>Notifications</h3>
        <p>Tu n'es prévenu que lorsque c'est utile : <b>ta décision est nécessaire</b> pour continuer (arrêt ⏸ d'une commande),
        <b>Claude attend ton autorisation</b>, <b>tout est terminé</b> (aucun agent encore au travail, tâche d'au moins 30 s), ou
        <b>un agent passe la main à un autre</b>. Chaque message dit quoi faire et sur quelle feature. Réglages : <code>${esc(D.home)}/config.json</code>
        (ou <code>${esc(P)}dashboard notifications</code>).</p>
        <ul class="list" style="padding:0"><li>${icon('monitor-smartphone', 'sm')} <span><b>Sur l'ordinateur</b> : notification du système (Windows, macOS, Linux) — <code>"desktop": true</code>.</span></li>
          <li>${icon('bell', 'sm')} <span><b>Sur le téléphone</b> : application <b>ntfy</b>, gratuite et sans compte. Choisis un sujet long et imprévisible, abonne-toi dans l'application, puis renseigne <code>"topic"</code>.</span></li>
          <li>${icon('shield-check', 'sm')} <span>Les notifications ne contiennent que le projet, l'étape et la branche : jamais de code ni de texte de Claude.</span></li></ul></section>
      <section id="d-depannage" class="card block"><h3>Dépannage</h3><dl class="faq">
          <dt>Sous PowerShell, <code>bash</code> lance WSL au lieu de Git Bash.</dt><dd>Utilise Git Bash, ou <code>&amp; "C:\\Program Files\\Git\\bin\\bash.exe"</code>.</dd>
          <dt>Des dizaines d'erreurs Testcontainers dans les tests.</dt><dd>Docker Desktop n'est pas démarré.</dd>
          <dt>Après une mise à jour, Claude utilise encore l'ancienne version du kit.</dt><dd>Relance Claude. Si le problème persiste, désinstalle le plugin, supprime son dossier dans <code>~/.claude/plugins/cache/top</code>, puis réinstalle-le.</dd>
          <dt>Aucune notification Windows.</dt><dd>Paramètres Windows › Notifications : autorise « Windows PowerShell », et vérifie que le mode Ne pas déranger est désactivé.</dd>
          <dt>Un projet n'apparaît pas ici.</dt><dd>Il doit être initialisé (<code>.claude/factory.json</code>) et Claude doit y avoir été ouvert au moins une fois depuis la v4.3.</dd>
        </dl></section>
    </div></div>`;
  }

  // ---------- Navigation et actualisation ----------
  function render() {
    const h = location.hash || '#/';
    let html, active;
    if (h.startsWith('#/projet/')) { html = viewProject(decodeURIComponent(h.slice(9))); active = 'projets'; }
    else if (h.startsWith('#/projets')) { html = viewProjects(); active = 'projets'; }
    else if (h.startsWith('#/docs')) { html = viewDocs(); active = 'docs'; }
    else { html = viewOverview(); active = 'home'; }
    document.getElementById('nav').innerHTML =
      `<a href="#/" class="${active === 'home' ? 'active' : ''}">${icon('layout-dashboard')} Vue d'ensemble${todo.length ? `<span class="count alert">${todo.length}</span>` : ''}</a>` +
      `<a href="#/projets" class="${active === 'projets' ? 'active' : ''}">${icon('folder-kanban')} Projets<span class="count">${projects.length}</span></a>` +
      `<a href="#/docs" class="${active === 'docs' ? 'active' : ''}">${icon('book-open')} Documentation</a>`;
    document.getElementById('view').innerHTML = html;
    document.querySelectorAll('[data-icon]').forEach(el => { el.innerHTML = icon(el.dataset.icon); });
    document.querySelectorAll('.toc a').forEach(a => a.addEventListener('click', ev => { ev.preventDefault(); const t = document.getElementById(a.dataset.anchor); if (t) t.scrollIntoView({ behavior: 'smooth' }); }));
    document.title = (todo.length ? `(${todo.length}) ` : '') + 'Top Factory';
  }
  let auto = true;
  try { auto = sessionStorage.getItem('tf-auto') !== 'off'; } catch (e) {}
  function drawAuto() {
    document.getElementById('auto').innerHTML = icon(auto ? 'loader-circle' : 'circle-pause', 'sm') + (auto ? ' Actualisation auto : active' : ' Actualisation auto : en pause');
    document.getElementById('updated').textContent = 'Mis à jour ' + ago(D.generated);
  }
  document.getElementById('auto').addEventListener('click', () => { auto = !auto; try { sessionStorage.setItem('tf-auto', auto ? 'on' : 'off'); } catch (e) {} drawAuto(); });
  document.getElementById('kit').textContent = D.kit ? 'Kit v' + D.kit : '';
  let theme = 'auto';
  try { theme = localStorage.getItem('tf-theme') || 'auto'; } catch (e) {}
  function drawTheme() {
    const opts = [['auto', 'monitor-smartphone', 'Auto'], ['light', 'sun', 'Clair'], ['dark', 'moon', 'Sombre']];
    const html = opts.map(([k, ic, l]) => `<button type="button" data-theme-choice="${k}" aria-pressed="${theme === k}" title="Thème ${l.toLowerCase()}">${icon(ic, 'sm')}<span>${l}</span></button>`).join('');
    ['theme', 'theme-m'].forEach(id => { const el = document.getElementById(id); if (el) el.innerHTML = html; });
    if (theme === 'auto') document.documentElement.removeAttribute('data-theme'); else document.documentElement.setAttribute('data-theme', theme);
  }
  document.addEventListener('click', ev => {
    const b = ev.target.closest('[data-theme-choice]'); if (!b) return;
    theme = b.dataset.themeChoice; try { localStorage.setItem('tf-theme', theme); } catch (e) {} drawTheme();
  });
  drawTheme();
  window.addEventListener('hashchange', () => { render(); window.scrollTo(0, 0); });
  render(); drawAuto();
  try { const y = sessionStorage.getItem('tf-scroll'); if (y) { window.scrollTo(0, +y); sessionStorage.removeItem('tf-scroll'); } } catch (e) {}
  setInterval(() => {
    drawAuto();
    if (!auto || document.visibilityState !== 'visible' || (location.hash || '').startsWith('#/docs')) return;
    try { sessionStorage.setItem('tf-scroll', String(window.scrollY)); } catch (e) {}
    location.reload();
  }, 15000);
})();
</script>
</body>
</html>
TF_HTML_END
} > "$tmp" && mv "$tmp" "$out"

if [ "${1:-}" = "--open" ]; then
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) cmd.exe //c start "" "$(cygpath -w "$out" 2>/dev/null || echo "$out")" >/dev/null 2>&1 ;;
    Darwin) open "$out" ;;
    *) command -v xdg-open >/dev/null 2>&1 && xdg-open "$out" >/dev/null 2>&1 ;;
  esac
  echo "$out"
fi
exit 0
