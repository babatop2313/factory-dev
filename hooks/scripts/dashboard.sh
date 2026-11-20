#!/usr/bin/env bash
# Génère le tableau de bord de la factory : ${TOP_FACTORY_HOME:-~/.top-factory}/dashboard.html
# (page autonome, sans serveur, rafraîchie toutes les 15 s) à partir de projects.json et des journaux events/*.jsonl.
#
#   bash dashboard.sh            régénère la page
#   bash dashboard.sh --open     régénère et l'ouvre dans le navigateur
#   bash dashboard.sh --prune    retire du registre les projets dont le dossier n'existe plus
#   bash dashboard.sh --path     affiche le chemin de la page
set -uo pipefail
command -v jq >/dev/null 2>&1 || { echo "jq est requis pour le tableau de bord." >&2; exit 1; }

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

# --- Données : un objet par projet (registre + 200 derniers événements + specs + Git) ---
projects="[]"
for id in $(jq -r 'keys[]' "$reg" 2>/dev/null); do
  p=$(jq -r --arg id "$id" '.[$id].path' "$reg")
  ev="[]"
  [ -f "$home/events/$id.jsonl" ] && ev=$(tail -n 200 "$home/events/$id.jsonl" | jq -cs '[.[] | objects]' 2>/dev/null || echo "[]")
  exists=false; specs="[]"; br=""; last=""
  if [ -d "$p" ]; then
    exists=true
    br=$(git -C "$p" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    last=$(git -C "$p" log -1 --format='%s|%cI' 2>/dev/null | cut -c1-200 || true)
    if [ -d "$p/docs/specs" ]; then
      specs=$(for f in "$p"/docs/specs/*.md; do
                [ -f "$f" ] || continue
                printf '%s\t%s\n' "$(basename "$f")" "$(date -r "$f" +%s 2>/dev/null || echo 0)"
              done | sort -t"$(printf '\t')" -k2 -nr | head -12 \
              | jq -Rcs 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], mtime: (.[1] | tonumber)})')
    fi
  fi
  projects=$(jq -c --arg id "$id" --slurpfile r "$reg" --argjson ev "$ev" --argjson specs "$specs" \
                --argjson exists "$exists" --arg br "$br" --arg last "$last" \
    '. + [$r[0][$id] + {id: $id, exists: $exists, branch: $br, lastCommit: $last, specs: $specs, events: $ev}]' \
    <<< "$projects")
done
data=$(jq -cn --argjson p "$projects" --arg g "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{generated: $g, projects: $p}' \
       | sed 's#</#<\\/#g')

tmp="$out.$$.tmp"
{
cat <<'HTML'
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="15">
<title>Top Factory — tableau de bord</title>
<style>
  :root { --bg:#f6f7fb; --card:#fff; --text:#1d2433; --muted:#5f6b7a; --line:#e3e7ef;
          --orange:#c2410c; --orange-bg:#fff1e6; --blue:#1d4ed8; --blue-bg:#e8efff;
          --green:#15803d; --green-bg:#e7f6ec; --grey:#6b7280; --grey-bg:#f0f1f4; --red:#b91c1c; --red-bg:#fdecec; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#11151d; --card:#1a202b; --text:#e6e9ef; --muted:#9aa4b2; --line:#2a3240;
            --orange:#fb923c; --orange-bg:#3a2414; --blue:#93b4ff; --blue-bg:#1b2a4a;
            --green:#6ee7a0; --green-bg:#14301f; --grey:#a3a9b5; --grey-bg:#252b36; --red:#fca5a5; --red-bg:#3b1b1b; }
  }
  * { box-sizing: border-box; }
  body { margin:0; font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; background:var(--bg); color:var(--text); }
  header { padding:20px 24px 8px; display:flex; flex-wrap:wrap; align-items:baseline; gap:8px 16px; }
  h1 { margin:0; font-size:22px; }
  .sub { color:var(--muted); font-size:13px; }
  main { padding:8px 24px 32px; max-width:1300px; }
  .counters { display:flex; flex-wrap:wrap; gap:12px; margin:8px 0 20px; }
  .counter { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:12px 16px; min-width:170px; }
  .counter b { display:block; font-size:26px; }
  .counter.todo b { color:var(--orange); } .counter.work b { color:var(--blue); }
  h2 { font-size:16px; margin:24px 0 10px; }
  .todo-list { display:grid; gap:8px; }
  .todo-item { background:var(--orange-bg); border:1px solid var(--orange); border-radius:10px; padding:10px 14px; }
  .todo-item b { color:var(--orange); }
  .empty { color:var(--muted); font-style:italic; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(360px,1fr)); gap:16px; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:16px; display:flex; flex-direction:column; gap:10px; }
  .card h3 { margin:0; font-size:18px; display:flex; justify-content:space-between; gap:8px; align-items:center; }
  .path { color:var(--muted); font-size:12px; word-break:break-all; }
  .status { border-radius:10px; padding:10px 12px; font-weight:600; }
  .status small { display:block; font-weight:400; color:var(--muted); margin-top:2px; }
  .s-orange { background:var(--orange-bg); color:var(--orange); } .s-blue { background:var(--blue-bg); color:var(--blue); }
  .s-green { background:var(--green-bg); color:var(--green); } .s-grey { background:var(--grey-bg); color:var(--grey); }
  .s-red { background:var(--red-bg); color:var(--red); }
  dl { display:grid; grid-template-columns:auto 1fr; gap:2px 12px; margin:0; font-size:13px; }
  dt { color:var(--muted); } dd { margin:0; word-break:break-word; }
  details { font-size:13px; } summary { cursor:pointer; color:var(--muted); }
  ol.timeline { list-style:none; margin:8px 0 0; padding:0; display:grid; gap:6px; }
  ol.timeline li { display:grid; grid-template-columns:22px 1fr; gap:6px; }
  .when { color:var(--muted); font-size:12px; }
  .detail { color:var(--muted); font-size:12px; }
  ul.specs { margin:6px 0 0; padding-left:18px; }
  .legend { display:grid; grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:8px; font-size:13px; }
  .legend div { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:8px 10px; }
  footer { color:var(--muted); font-size:12px; margin-top:28px; }
  code { font-size:12px; }
</style>
</head>
<body>
<header>
  <h1>🏭 Top Factory — tableau de bord</h1>
  <span class="sub" id="generated"></span>
</header>
<main>
  <section class="counters" id="counters"></section>
  <h2>👉 À traiter maintenant</h2>
  <div class="todo-list" id="todo"></div>
  <h2>📁 Projets</h2>
  <div class="grid" id="projects"></div>
  <h2>ℹ️ Que signifie chaque état ?</h2>
  <div class="legend" id="legend"></div>
  <footer>Page générée par la factory à chaque événement et rechargée toutes les 15 secondes.
    Elle reste sur ton poste : aucune donnée n'est envoyée ailleurs. Notifications et réglages : <code id="conf"></code></footer>
</main>
<script id="data" type="application/json">
HTML
printf '%s\n' "$data"
cat <<'HTML'
</script>
<script>
(function () {
  const data = JSON.parse(document.getElementById('data').textContent);
  const STATES = {
    validation:    { icon: '⏸️', label: 'Validation requise', cls: 's-orange', todo: true,
                     help: 'Claude s\'est arrêté à une étape de validation (spec, plan, verdict de revue…) : lis sa proposition et réponds.' },
    permission:    { icon: '🔐', label: 'Autorisation demandée', cls: 's-orange', todo: true,
                     help: 'Claude attend ton accord pour lancer une commande ou modifier un fichier.' },
    attention:     { icon: '💬', label: 'Claude attend ta réponse', cls: 's-orange', todo: true,
                     help: 'Claude t\'a posé une question ou attend une consigne pour continuer.' },
    agent_start:   { icon: '⚙️', label: 'Un agent travaille', cls: 's-blue', work: true,
                     help: 'Un agent (spec-writer, architect, backend-dev, frontend-dev, test-writer, reviewer) est en cours.' },
    session_start: { icon: '▶️', label: 'Session ouverte', cls: 's-blue',
                     help: 'Claude vient d\'être lancé sur ce projet.' },
    agent_end:     { icon: '✅', label: 'Un agent a terminé', cls: 's-blue', work: true,
                     help: 'Un agent a rendu son travail ; Claude enchaîne avec l\'étape suivante.' },
    turn_end:      { icon: '✔️', label: 'Claude a terminé — à toi de jouer', cls: 's-green', todo: true,
                     help: 'Claude a fini ce que tu lui as demandé et te rend la main.' },
    commit:        { icon: '📦', label: 'Commit effectué', cls: 's-green', help: 'Un commit vient d\'être créé.' },
    push:          { icon: '🚀', label: 'Branche poussée', cls: 's-green', help: 'La branche a été poussée : une PR peut être ouverte.' },
    session_end:   { icon: '⏹️', label: 'Session fermée', cls: 's-grey', help: 'Claude a été fermé sur ce projet.' },
    idle:          { icon: '💤', label: 'Inactif', cls: 's-grey', help: 'Aucune activité depuis plus de 24 heures.' },
    missing:       { icon: '⚠️', label: 'Dossier introuvable', cls: 's-red', help: 'Le projet a été déplacé ou supprimé (dashboard.sh --prune le retire).' },
  };
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const ago = iso => {
    const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
    if (s < 60) return 'à l\'instant';
    if (s < 3600) return 'il y a ' + Math.floor(s / 60) + ' min';
    if (s < 86400) return 'il y a ' + Math.floor(s / 3600) + ' h';
    return 'il y a ' + Math.floor(s / 86400) + ' j';
  };
  const fmt = iso => new Date(iso).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' });

  function stateOf(p) {
    if (!p.exists) return { key: 'missing' };
    const ev = p.events || [];
    if (!ev.length) return { key: 'idle' };
    const last = ev[ev.length - 1];
    if ((Date.now() - new Date(last.ts).getTime()) > 86400000) return { key: 'idle', ev: last };
    // Un agent démarré sans fin correspondante après lui : il travaille encore.
    if (last.kind === 'agent_end') {
      let open = 0;
      for (const e of ev.slice(-30)) { if (e.kind === 'agent_start') open++; if (e.kind === 'agent_end') open = Math.max(0, open - 1); }
      if (open > 0) return { key: 'agent_start', ev: last };
    }
    return { key: STATES[last.kind] ? last.kind : 'idle', ev: last };
  }

  const projects = (data.projects || []).map(p => ({ ...p, state: stateOf(p) }))
    .sort((a, b) => ((b.events || []).slice(-1)[0]?.ts || '').localeCompare((a.events || []).slice(-1)[0]?.ts || ''));

  document.getElementById('generated').textContent = 'Mis à jour ' + fmt(data.generated);
  document.getElementById('conf').textContent = '~/.top-factory/config.json';

  const todo = projects.filter(p => STATES[p.state.key].todo);
  const work = projects.filter(p => STATES[p.state.key].work);
  document.getElementById('counters').innerHTML =
    `<div class="counter"><b>${projects.length}</b>projet(s) suivi(s)</div>` +
    `<div class="counter todo"><b>${todo.length}</b>attend(ent) une action de ta part</div>` +
    `<div class="counter work"><b>${work.length}</b>en cours de travail</div>`;

  document.getElementById('todo').innerHTML = todo.length ? todo.map(p => {
    const st = STATES[p.state.key], e = p.state.ev || {};
    return `<div class="todo-item">${st.icon} <b>${esc(p.name)}</b> — ${esc(e.title || st.label)}` +
           (e.branch ? ` · branche <code>${esc(e.branch)}</code>` : '') +
           (e.detail ? `<div class="detail">${esc(e.detail)}</div>` : '') +
           `<div class="when">${e.ts ? ago(e.ts) : ''}</div></div>`;
  }).join('') : '<p class="empty">Rien ne t\'attend : tout est en ordre ou en cours.</p>';

  document.getElementById('projects').innerHTML = projects.length ? projects.map(p => {
    const st = STATES[p.state.key], e = p.state.ev || {};
    const lc = (p.lastCommit || '').split('|');
    const timeline = (p.events || []).slice(-15).reverse().map(ev => {
      const s = STATES[ev.kind] || { icon: '•' };
      return `<li><span>${s.icon}</span><span>${esc(ev.title)}` +
             (ev.detail ? `<div class="detail">${esc(ev.detail)}</div>` : '') +
             `<div class="when">${fmt(ev.ts)}${ev.branch ? ' · ' + esc(ev.branch) : ''}</div></span></li>`;
    }).join('');
    const specs = (p.specs || []).map(s => `<li>${esc(s.name)} <span class="when">· ${s.mtime ? fmt(new Date(s.mtime * 1000).toISOString()) : ''}</span></li>`).join('');
    return `<article class="card">
      <h3>${esc(p.name)} <span class="when">${e.ts ? ago(e.ts) : ''}</span></h3>
      <div class="path">${esc(p.path)}</div>
      <div class="status ${st.cls}">${st.icon} ${esc(p.state.key === 'idle' || p.state.key === 'missing' ? st.label : (e.title || st.label))}${e.detail ? `<small>${esc(e.detail)}</small>` : ''}</div>
      <dl>
        <dt>Branche</dt><dd>${p.branch ? `<code>${esc(p.branch)}</code>` : '—'}</dd>
        <dt>Dernier commit</dt><dd>${lc[0] ? esc(lc[0]) + (lc[1] ? ` <span class="when">· ${fmt(lc[1])}</span>` : '') : '—'}</dd>
        <dt>Architecture</dt><dd>${esc(p.architecture || '—')}</dd>
        <dt>Dossiers</dt><dd>backend : <code>${esc(p.backend || '—')}</code> · frontend : <code>${esc(p.frontend == null ? 'aucun' : p.frontend)}</code></dd>
        <dt>Kit</dt><dd>${esc(p.kit ? 'v' + p.kit : '—')}</dd>
      </dl>
      <details ${p.state.key !== 'idle' ? 'open' : ''}><summary>Activité récente (${(p.events || []).length} événement(s))</summary>
        <ol class="timeline">${timeline || '<li class="empty">Aucune activité enregistrée.</li>'}</ol></details>
      <details><summary>Specs et plans (${(p.specs || []).length})</summary>
        ${specs ? `<ul class="specs">${specs}</ul>` : '<p class="empty">Aucun fichier dans docs/specs.</p>'}</details>
    </article>`;
  }).join('') : '<p class="empty">Aucun projet pour l\'instant : ouvre Claude dans un projet initialisé avec la factory, il apparaîtra ici.</p>';

  document.getElementById('legend').innerHTML = Object.values(STATES)
    .map(s => `<div><b>${s.icon} ${esc(s.label)}</b><br>${esc(s.help)}</div>`).join('');
})();
</script>
</body>
</html>
HTML
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
