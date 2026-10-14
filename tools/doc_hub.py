# Génère docs/hub/index.html : TOUTE la documentation RoadLine dans un seul fichier HTML, lisible hors ligne (double-clic),
# rangée par catégories, avec recherche, cases à cocher sauvegardées dans le navigateur (backtest + priorités), notes,
# export / import de l'avancement (.json), rapport texte et impression.
# À relancer après chaque mise à jour de la doc : python3 tools/doc_hub.py (fait aussi par tests/run.sh pour vérifier).
import ast
import html
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, 'docs')
OUT = os.path.join(DOCS, 'hub', 'index.html')

CATEGORIES = [
    ('Pilotage', 'Où on en est, ce qui reste, la stratégie', [
        ('ETAT_PROJET', 'État du projet (point de sauvegarde)'), ('ROADMAP', 'Feuille de route'),
        ('STRATEGIE', 'Stratégie et positionnement'), ('PROPOSITIONS', 'Propositions et idées'),
        ('V1_CHECKLIST', 'Checklist V1')]),
    ('La ville', 'Ce que vivent les joueurs', [
        ('FEATURES', 'Fonctionnalités et signatures'), ('JOBS', 'Métiers'), ('REGLEMENT', 'Règlement'),
        ('VEHICULES', 'Véhicules'), ('WEATHER', 'Météo événementielle'), ('FAQ_FIVEM', 'FAQ FiveM (joueurs)'),
        ('JOUER_A_PLUSIEURS', 'Jouer à plusieurs')]),
    ('Staff', 'Modération, Discord, sécurité, boutique', [
        ('ADMIN', 'Administration (F10 / F11)'), ('ALERTES', 'Alertes et console'), ('DISCORD', 'Discord et bot'),
        ('SECURITY', 'Sécurité et anti-triche'), ('BOUTIQUE', 'Boutique'), ('BOUTIQUE_LEGAL', 'Boutique : cadre légal')]),
    ('Maps et mods', 'Importer, ranger, vérifier', [
        ('IMPORTER_MODS', 'Importer des mods'), ('MLO', 'Intérieurs (MLO)'), ('SELECTION_MAPPINGS', 'Sélection des mappings'),
        ('BOB74_IPL', 'Intérieurs du jeu (IPL)'), ('VEHICULES_ADDON', 'Véhicules ajoutés'), ('PHOTOS', 'Photos et captures')]),
    ('Technique', 'Serveur, installation, hébergement', [
        ('INSTALL', 'Installation'), ('OVH', 'VPS OVH'), ('PERFORMANCE', 'Performance'), ('ARCHITECTURE', 'Architecture'),
        ('V1_RESOURCES', 'Ressources V1'), ('AGENTS', 'Règles pour les agents (Claude)'),
        ('PROMPT_REPRISE', 'Reprendre dans une autre session (Claude)'), ('AUDIT_V12_35', 'Audit global (12/10)')]),
]

# Priorités jusqu'à l'ouverture (20/10/2026) : cochables dans le site. À tenir à jour ici.
PRIORITIES = [
    ('Urgent (avant de rouvrir la bêta)', [
        'METTRE-A-JOUR puis METTRE-A-JOUR-OVH (retouches Qbox : pop-up police, soins ; maps Patoche tranchées)',
        'Démarrage : aucune ligne rouge (maps « NON démarrée », scripts Patoche : stand de jeux, circuit, FastBox, villa bunker)',
        'Les 9 zips ROADTRIP-… (coiffures et tenues converties) dans mods-a-trier → IMPORTER-MODS → METTRE-A-JOUR-OVH',
        'IMPORTER-MODS relancé (V12.48) : patoche_interact sous son vrai nom → script de la villa bunker installé ; scripts billard / football remis dans mods-a-trier',
        'Version V12.58+ sur le PC ET sur le VPS (console : [RoadLine RP] version …)',
    ]),
    ('Priorité haute (cette semaine)', [
        'Backtest allégé (onglet Backtest, 31 tests) en commençant par les ★★★',
        'Caler en jeu : points du mécano sur la map Benny\'s, véhicules d\'exposition + départ des essais, portes /doorlock',
        'Personnalisation : envoyer Improved Females (visages), corps femme (Muscular Body / Improved Lower Body), cardigan cœur, chignon',
        'Récolte : vérifier les champs (céréales, tabac, pavot) et la hauteur du mobilier ; nouvelles coupes / robes au coiffeur et au magasin',
        'Doublons de lieux (casino, concession, Ammu-Nation, prison) : « nouveau » ou « ancien » pour chacun',
        'Prison : coordonnées de cellule et de sortie avec la map prison',
        'Sauvegardes de la base : GERER-OVH → sauvegarde présente du jour',
    ]),
    ('Avant l\'ouverture du 20/10', [
        'Test de charge (6 à 10 joueurs, 1 h, resmon)',
        'Boutique : prix, packs, RoadCoins, adresse Tebex, conformité PLA → Config.Enabled',
        'Annonce publique sur Discord et serveurs partenaires ; rôles Discord et staff vérifiés',
        'Redémarrage automatique de 6 h vérifié sur le VPS',
    ]),
    ('Après l\'ouverture', [
        'entityLockdown strict (sécurité)', 'Audit des ~300 points d\'entrée réseau',
        'Cabines téléphoniques : refonte', 'Skate en location (véhicule invisible + planche) : à étudier',
        'Mises à jour ox_lib / ox_inventory / oxmysql (à tester sur le PC d\'abord)',
    ]),
]


GUIDES = [
    ('GUIDE_JOUEUR', 'Guide du joueur', 'guide_joueur', lambda m: m.build()),
    ('GUIDE_ROADLINE', 'Guide RoadLine (lieux, points, carte)', 'pdf', lambda m: m.guide(__import__('json').load(open('tools/points.json', encoding='utf-8')))),
    ('GUIDE_STAFF', 'Guide du staff', 'guide_staff', lambda m: m.build()),
]


def _markup(t):
    """Balises reportlab → markdown simple."""
    t = re.sub(r'<br\s*/?>', ' ', str(t))
    t = re.sub(r'</?b>', '**', t)
    t = re.sub(r'</?i>', '*', t)
    t = re.sub(r'<[^>]+>', '', t)
    t = html.unescape(t).replace('\n', ' ')
    return re.sub(r'\s+', ' ', t).replace('****', '').strip()


def _flow_md(f, out):
    from reportlab.platypus import Paragraph, Table
    if isinstance(f, (list, tuple)):
        for x in f:
            _flow_md(x, out)
    elif isinstance(f, Paragraph):
        txt = _markup(f.text)
        if not txt:
            return
        name = getattr(f.style, 'name', '')
        if name == 'h1': out.append('\n# ' + txt.replace('**', ''))
        elif name == 'h2': out.append('\n## ' + txt.replace('**', ''))
        elif name == 'h3': out.append('\n### ' + txt.replace('**', ''))
        elif name == 'k': out.append('\n**' + txt.replace('**', '') + '**')
        elif name in ('tip', 'warn'): out.append('\n> ' + txt)
        elif txt.startswith('• '): out.append('- ' + txt[2:])
        else: out.append('\n' + txt)
    elif isinstance(f, Table):
        rows = [[_markup(c.text if isinstance(c, Paragraph) else ' '.join(_markup(x.text) for x in c if isinstance(x, Paragraph)) if isinstance(c, (list, tuple)) else c).replace('|', '/') for c in r] for r in f._cellvalues]
        rows = [r for r in rows if any(r)]
        if rows:
            out.append('')
            out.append('| ' + ' | '.join(rows[0]) + ' |')
            out.append('|' + '---|' * len(rows[0]))
            out += ['| ' + ' | '.join(r) + ' |' for r in rows[1:]]
            out.append('')
    else:
        for attr in ('_content', '_flowables'):
            if isinstance(getattr(f, attr, None), (list, tuple)):
                _flow_md(getattr(f, attr), out)


def guides_md():
    """Texte des guides PDF, pris dans les MÊMES données que les PDF (rien n'est réécrit à la main)."""
    import importlib
    from reportlab.platypus import doctemplate
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    cwd = os.getcwd()
    os.chdir(ROOT)
    captured = []
    real = doctemplate.BaseDocTemplate.build
    doctemplate.BaseDocTemplate.build = lambda self, flowables, *a, **k: captured.append(list(flowables))
    out = {}
    try:
        import contextlib, io
        for key, _, mod, run in GUIDES:
            captured.clear()
            with contextlib.redirect_stdout(io.StringIO()):
                run(importlib.import_module(mod))
            if captured:
                lines = []
                _flow_md(captured[-1], lines)
                out[key] = '\n'.join(lines).strip() + '\n'
    finally:
        doctemplate.BaseDocTemplate.build = real
        os.chdir(cwd)
    return out


def backtest_sessions():
    tree = ast.parse(open(os.path.join(ROOT, 'tools', 'backtest.py'), encoding='utf-8').read())
    for node in tree.body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], 'id', '') == 'SESSIONS':
            return ast.literal_eval(node.value)
    return []


def version():
    m = re.search(r"VERSION = '([^']+)'", open(os.path.join(ROOT, 'tools', 'pdf.py'), encoding='utf-8').read())
    return m.group(1) if m else '?'


def build():
    docs, missing = {}, []
    guides = guides_md()
    CATEGORIES.insert(1, ('Guides', 'Le contenu des guides PDF, consultable et cherchable : quoi, où, comment', [(k, t) for k, t, _, _ in GUIDES if k in guides]))
    for _, _, items in CATEGORIES:
        for key, _ in items:
            if key in guides:
                docs[key] = guides[key]
    for _, _, items in CATEGORIES:
        for key, _ in items:
            p = os.path.join(DOCS, key + '.md')
            if key in docs:
                continue
            if os.path.isfile(p):
                docs[key] = open(p, encoding='utf-8').read()
            else:
                missing.append(key)
    listed = {k for _, _, items in CATEGORIES for k, _ in items}
    extra = sorted(f[:-3] for f in os.listdir(DOCS) if f.endswith('.md') and f[:-3] not in listed)
    if extra:
        CATEGORIES.append(('Autres', 'Documents pas encore classés', [(k, k.replace('_', ' ').title()) for k in extra]))
        for k in extra:
            docs[k] = open(os.path.join(DOCS, k + '.md'), encoding='utf-8').read()
    pdfs = sorted(f for f in os.listdir(os.path.join(DOCS, 'pdf')) if f.endswith('.pdf')) if os.path.isdir(os.path.join(DOCS, 'pdf')) else []
    data = {
        'version': version(),
        'categories': [{'name': n, 'desc': d, 'items': [{'key': k, 'title': t} for k, t in items if k in docs]} for n, d, items in CATEGORIES],
        'docs': docs,
        'backtest': [{'title': t, 'tests': [{'text': x[0], 'who': x[1], 'prio': x[2]} for x in tests]} for t, tests in backtest_sessions()],
        'priorities': [{'title': t, 'items': items} for t, items in PRIORITIES],
        'pdfs': pdfs,
    }
    payload = json.dumps(data, ensure_ascii=False).replace('</', '<\\/')
    page = TEMPLATE.replace('__DATA__', payload).replace('__VERSION__', html.escape(data['version']))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)
    return data, missing


TEMPLATE = r'''<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Documentation RoadLine</title>
<style>
:root{--bg:#0f1115;--panel:#171a21;--panel2:#1e222b;--text:#e8e9ed;--muted:#9aa0ac;--line:#2a2f3a;--accent:#ff3d7f;--ok:#3ecf8e;--warn:#f5b041;--bad:#ff5c5c;--code:#0b0d11}
:root[data-theme="light"]{--bg:#f6f7f9;--panel:#fff;--panel2:#f0f2f5;--text:#16181d;--muted:#5b6170;--line:#dfe2e8;--accent:#d61f63;--ok:#1f9d63;--warn:#b7791f;--bad:#c53030;--code:#eef0f4}
@media (prefers-color-scheme: light){:root:not([data-theme="dark"]){--bg:#f6f7f9;--panel:#fff;--panel2:#f0f2f5;--text:#16181d;--muted:#5b6170;--line:#dfe2e8;--accent:#d61f63;--ok:#1f9d63;--warn:#b7791f;--bad:#c53030;--code:#eef0f4}}
*{box-sizing:border-box}html,body{margin:0;background:var(--bg);color:var(--text);font:15px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
a{color:var(--accent)}header{position:sticky;top:0;z-index:5;display:flex;gap:12px;align-items:center;padding:10px 16px;background:var(--panel);border-bottom:1px solid var(--line)}
header h1{font-size:17px;margin:0;white-space:nowrap}header h1 span{color:var(--accent)}
#q{flex:1;min-width:0;padding:8px 12px;border-radius:8px;border:1px solid var(--line);background:var(--panel2);color:var(--text)}
button,.btn{cursor:pointer;padding:7px 11px;border-radius:8px;border:1px solid var(--line);background:var(--panel2);color:var(--text);font:inherit;font-size:13px;white-space:nowrap}
button:hover{border-color:var(--accent)}#menuBtn{display:none}
.wrap{display:flex;min-height:calc(100vh - 56px)}nav{width:290px;flex:none;border-right:1px solid var(--line);background:var(--panel);padding:12px;overflow:auto;position:sticky;top:56px;height:calc(100vh - 56px)}
nav h3{font-size:12px;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:16px 6px 4px}nav small{display:block;color:var(--muted);margin:0 6px 4px;font-size:12px}
nav a{display:block;padding:5px 8px;border-radius:6px;text-decoration:none;color:var(--text);font-size:14px}nav a:hover,nav a.on{background:var(--panel2);color:var(--accent)}
main{flex:1;min-width:0;padding:20px 28px 80px;max-width:1000px}
.doc h1{font-size:26px;border-bottom:2px solid var(--accent);padding-bottom:6px}.doc h2{font-size:20px;margin-top:28px;border-bottom:1px solid var(--line);padding-bottom:4px}.doc h3{font-size:17px}
.doc code{background:var(--code);padding:1px 5px;border-radius:4px;font-size:13px}.doc pre{background:var(--code);padding:12px;border-radius:8px;overflow:auto}.doc pre code{padding:0}
.doc table{border-collapse:collapse;width:100%;display:block;overflow:auto}.doc td,.doc th{border:1px solid var(--line);padding:6px 8px;vertical-align:top}.doc th{background:var(--panel2)}
.doc blockquote{border-left:3px solid var(--accent);margin:0;padding:4px 14px;color:var(--muted)}
.card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px;margin:12px 0}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}
.stat b{display:block;font-size:26px;color:var(--accent)}.muted{color:var(--muted)}
.item{display:flex;gap:10px;align-items:flex-start;padding:8px 6px;border-bottom:1px solid var(--line)}.item:last-child{border-bottom:0}
.item input[type=checkbox]{width:18px;height:18px;margin-top:3px;flex:none;accent-color:var(--ok)}.item.done .txt{text-decoration:line-through;color:var(--muted)}
.item .txt{flex:1;min-width:0}.tag{display:inline-block;font-size:11px;padding:1px 7px;border-radius:99px;border:1px solid var(--line);color:var(--muted);margin-right:4px}
.p3{color:var(--bad);border-color:var(--bad)}.p2{color:var(--warn);border-color:var(--warn)}
.note{width:100%;margin-top:6px;padding:6px 8px;border-radius:6px;border:1px solid var(--line);background:var(--panel2);color:var(--text);font:inherit;font-size:13px;resize:vertical;min-height:32px}
.bar{height:8px;background:var(--panel2);border-radius:99px;overflow:hidden}.bar i{display:block;height:100%;background:var(--ok)}
.tools{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0}
.hit{padding:10px 12px;border:1px solid var(--line);border-radius:8px;margin:8px 0;cursor:pointer;background:var(--panel)}.hit:hover{border-color:var(--accent)}mark{background:var(--accent);color:#fff;border-radius:3px;padding:0 2px}
@media (max-width:820px){#menuBtn{display:inline-block}nav{position:fixed;left:0;top:56px;z-index:4;transform:translateX(-100%);transition:transform .2s;width:84vw}nav.open{transform:none;box-shadow:0 0 30px #0008}.grid{grid-template-columns:1fr 1fr}main{padding:16px}header h1 small{display:none}}
@media print{header,nav,.tools,.note{display:none!important}main{padding:0;max-width:none}.card{break-inside:avoid}}
</style>
</head>
<body>
<header>
  <button id="menuBtn" aria-label="Menu">☰</button>
  <h1>Road<span>Line</span> · docs <small class="muted">__VERSION__</small></h1>
  <input id="q" type="search" placeholder="Rechercher dans toute la documentation…">
  <button id="theme" title="Thème clair / sombre">◐</button>
</header>
<div class="wrap"><nav id="nav"></nav><main id="main"></main></div>
<script id="data" type="application/json">__DATA__</script>
<script>
(function () {
  'use strict';
  var D = JSON.parse(document.getElementById('data').textContent);
  var KEY = 'roadline-docs-v1';
  var state = { checks: {}, notes: {} };
  try { var saved = JSON.parse(localStorage.getItem(KEY) || 'null'); if (saved && saved.checks) state = saved; } catch (e) {}
  function save() { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {} }
  try { var th = localStorage.getItem(KEY + '-theme'); if (th) document.documentElement.dataset.theme = th; } catch (e) {}
  var $ = function (s) { return document.querySelector(s); };
  var esc = function (s) { return String(s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };

  // --- Markdown → HTML (titres, listes, tâches, tableaux, code, citations, liens, gras, italique) ---
  function inline(t) {
    t = esc(t);
    t = t.replace(/`([^`]+)`/g, '<code>$1</code>');
    t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>').replace(/(^|[^*])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>');
    t = t.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function (_, a, h) { return '<a href="' + h + '" target="_blank" rel="noopener">' + a + '</a>'; });
    return t;
  }
  function md(src, key) {
    var lines = src.replace(/\r/g, '').split('\n'), out = [], i = 0, task = 0;
    while (i < lines.length) {
      var l = lines[i];
      if (/^```/.test(l)) { var code = []; i++; while (i < lines.length && !/^```/.test(lines[i])) code.push(lines[i++]); i++; out.push('<pre><code>' + esc(code.join('\n')) + '</code></pre>'); continue; }
      var h = l.match(/^(#{1,4})\s+(.*)/); if (h) { out.push('<h' + h[1].length + ' id="' + slug(h[2]) + '">' + inline(h[2]) + '</h' + h[1].length + '>'); i++; continue; }
      if (/^\s*(---|\*\*\*)\s*$/.test(l)) { out.push('<hr>'); i++; continue; }
      if (/^\|/.test(l) && i + 1 < lines.length && /^\|?\s*:?-{2,}/.test(lines[i + 1])) {
        var row = function (r) { return r.replace(/^\||\|$/g, '').split('|').map(function (c) { return c.trim(); }); };
        var head = row(l); i += 2; var body = [];
        while (i < lines.length && /^\|/.test(lines[i])) body.push(row(lines[i++]));
        out.push('<table><tr>' + head.map(function (c) { return '<th>' + inline(c) + '</th>'; }).join('') + '</tr>' + body.map(function (r) { return '<tr>' + r.map(function (c) { return '<td>' + inline(c) + '</td>'; }).join('') + '</tr>'; }).join('') + '</table>');
        continue;
      }
      if (/^>\s?/.test(l)) { var q = []; while (i < lines.length && /^>\s?/.test(lines[i])) q.push(lines[i++].replace(/^>\s?/, '')); out.push('<blockquote>' + inline(q.join(' ')) + '</blockquote>'); continue; }
      if (/^\s*([-*]|\d+\.)\s+/.test(l)) {
        var ol = /^\s*\d+\./.test(l), items = [];
        while (i < lines.length && (/^\s*([-*]|\d+\.)\s+/.test(lines[i]) || (/^\s{2,}\S/.test(lines[i]) && items.length))) {
          var m = lines[i].match(/^(\s*)([-*]|\d+\.)\s+(.*)/);
          if (m) items.push({ depth: m[1].length, text: m[3] }); else items[items.length - 1].text += ' ' + lines[i].trim();
          i++;
        }
        out.push((ol ? '<ol>' : '<ul>') + items.map(function (it) {
          var tk = it.text.match(/^\[( |x)\]\s+(.*)/i), pad = it.depth ? ' style="margin-left:' + it.depth * 8 + 'px"' : '';
          if (tk) { var id = key + ':t' + (task++); return '<li' + pad + ' style="list-style:none"><label><input type="checkbox" data-id="' + id + '"' + ((state.checks[id] !== undefined ? state.checks[id] : tk[1] !== ' ') ? ' checked' : '') + '> ' + inline(tk[2]) + '</label></li>'; }
          return '<li' + pad + '>' + inline(it.text) + '</li>';
        }).join('') + (ol ? '</ol>' : '</ul>'));
        continue;
      }
      if (!l.trim()) { i++; continue; }
      var p = []; while (i < lines.length && lines[i].trim() && !/^(#{1,4}\s|```|\||>|\s*([-*]|\d+\.)\s)/.test(lines[i])) p.push(lines[i++]);
      if (!p.length) p.push(lines[i++]);
      out.push('<p>' + inline(p.join(' ')) + '</p>');
    }
    return out.join('\n');
  }
  function slug(s) { return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''); }

  // --- Navigation ---
  var title = {}; D.categories.forEach(function (c) { c.items.forEach(function (it) { title[it.key] = it.title; }); });
  function navHtml() {
    var h = '<a href="#accueil">🏠 Accueil</a><a href="#priorites">🚦 Priorités</a><a href="#backtest">✅ Backtest à cocher</a><a href="#pdf">📄 PDF</a>';
    D.categories.forEach(function (c) { h += '<h3>' + esc(c.name) + '</h3><small>' + esc(c.desc) + '</small>' + c.items.map(function (it) { return '<a href="#doc/' + it.key + '">' + esc(it.title) + '</a>'; }).join(''); });
    $('#nav').innerHTML = h;
  }
  function mark() { var h = location.hash || '#accueil'; Array.prototype.forEach.call(document.querySelectorAll('nav a'), function (a) { a.classList.toggle('on', a.getAttribute('href') === h); }); }

  // --- Listes à cocher (priorités, backtest) ---
  function itemHtml(id, text, tags) {
    var done = !!state.checks[id];
    return '<div class="item' + (done ? ' done' : '') + '"><input type="checkbox" data-id="' + esc(id) + '"' + (done ? ' checked' : '') + '><div class="txt">' + (tags || '') + inline(text) +
      '<textarea class="note" data-note="' + esc(id) + '" placeholder="Note (bug constaté, qui a testé…)">' + esc(state.notes[id] || '') + '</textarea></div></div>';
  }
  function progress(ids) { var n = ids.filter(function (id) { return state.checks[id]; }).length; return { n: n, t: ids.length, pct: ids.length ? Math.round(n * 100 / ids.length) : 0 }; }
  function btIds() { var a = []; D.backtest.forEach(function (s, si) { s.tests.forEach(function (_, ti) { a.push('bt:' + si + ':' + ti); }); }); return a; }
  function prIds() { var a = []; D.priorities.forEach(function (s, si) { s.items.forEach(function (_, ti) { a.push('pr:' + si + ':' + ti); }); }); return a; }
  function toolsHtml() { return '<div class="tools"><button data-act="export">💾 Exporter l\'avancement (.json)</button><button data-act="import">📂 Importer</button><button data-act="report">📝 Rapport texte</button><button data-act="print">🖨 Imprimer / PDF</button><button data-act="reset">↺ Tout décocher</button></div>'; }
  function bar(p) { return '<div class="bar"><i style="width:' + p.pct + '%"></i></div><p class="muted">' + p.n + ' / ' + p.t + ' (' + p.pct + ' %)</p>'; }

  var pages = {
    accueil: function () {
      var bt = progress(btIds()), pr = progress(prIds()), ndocs = Object.keys(D.docs).length;
      return '<div class="doc"><h1>Documentation RoadLine RP</h1><p class="muted">Version ' + esc(D.version) + ' · tout est dans ce fichier, lisible sans Internet. Les cases cochées et les notes restent dans ce navigateur : exporte-les pour les garder ou les partager.</p></div>' +
        '<div class="grid"><div class="card stat"><b>' + ndocs + '</b>documents</div><div class="card stat"><b>' + pr.pct + ' %</b>priorités faites</div><div class="card stat"><b>' + bt.pct + ' %</b>backtest validé</div><div class="card stat"><b>' + D.pdfs.length + '</b>PDF</div></div>' +
        '<div class="card"><h3>Par où commencer</h3><p><a href="#doc/ETAT_PROJET">État du projet</a> : le point complet, les versions, les règles. <a href="#priorites">Priorités</a> : ce qu\'il reste jusqu\'à l\'ouverture. <a href="#backtest">Backtest</a> : les tests en jeu à cocher.</p></div>' +
        D.categories.map(function (c) { return '<div class="card"><h3>' + esc(c.name) + '</h3><p class="muted">' + esc(c.desc) + '</p>' + c.items.map(function (it) { return '<a class="btn" style="display:inline-block;margin:3px;text-decoration:none" href="#doc/' + it.key + '">' + esc(it.title) + '</a>'; }).join('') + '</div>'; }).join('');
    },
    priorites: function () {
      return '<div class="doc"><h1>Priorités jusqu\'à l\'ouverture</h1></div>' + bar(progress(prIds())) + toolsHtml() +
        D.priorities.map(function (s, si) { return '<div class="card"><h3>' + esc(s.title) + '</h3>' + s.items.map(function (t, ti) { return itemHtml('pr:' + si + ':' + ti, t); }).join('') + '</div>'; }).join('');
    },
    backtest: function () {
      return '<div class="doc"><h1>Backtest en jeu</h1><p class="muted">Ce qui reste vraiment à tester, rangé en sessions. ★★★ = bloquant pour l\'ouverture.</p></div>' + bar(progress(btIds())) + toolsHtml() +
        D.backtest.map(function (s, si) { return '<div class="card"><h3>' + esc(s.title) + '</h3>' + s.tests.map(function (t, ti) {
          return itemHtml('bt:' + si + ':' + ti, t.text, '<span class="tag">' + esc(t.who) + '</span><span class="tag p' + t.prio + '">' + '★★★'.slice(0, t.prio) + '</span> ');
        }).join('') + '</div>'; }).join('');
    },
    pdf: function () {
      return '<div class="doc"><h1>PDF</h1><p class="muted">Fichiers du dossier docs/pdf (lien relatif : ce fichier doit rester dans docs/hub).</p><ul>' +
        D.pdfs.map(function (f) { return '<li><a href="../pdf/' + encodeURI(f) + '" target="_blank">' + esc(f.replace(/_/g, ' ').replace(/\.pdf$/, '')) + '</a></li>'; }).join('') + '</ul></div>';
    }
  };

  function render() {
    var h = decodeURIComponent((location.hash || '#accueil').slice(1)), html;
    if (h.indexOf('doc/') === 0) {
      var k = h.slice(4).split('#')[0];
      html = D.docs[k] ? '<div class="tools"><button data-act="print">🖨 Imprimer / PDF</button><button data-act="md" data-key="' + esc(k) + '">⬇ Télécharger (.md)</button></div><article class="doc">' + md(D.docs[k], k) + '</article>' : '<p>Document introuvable.</p>';
    } else if (h.indexOf('search/') === 0) {
      html = search(h.slice(7));
    } else html = (pages[h] || pages.accueil)();
    $('#main').innerHTML = html; mark(); window.scrollTo(0, 0); $('#nav').classList.remove('open');
  }

  // --- Recherche ---
  function search(q) {
    q = q.trim(); if (q.length < 2) return '<p class="muted">Tape au moins 2 lettres.</p>';
    var re = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'ig'), hits = [];
    Object.keys(D.docs).forEach(function (k) {
      var lines = D.docs[k].split('\n'), section = title[k] || k;
      lines.forEach(function (l) { var hh = l.match(/^#{1,4}\s+(.*)/); if (hh) section = hh[1]; re.lastIndex = 0; if (re.test(l)) hits.push({ k: k, section: section, line: l }); });
    });
    D.backtest.forEach(function (s) { s.tests.forEach(function (t) { re.lastIndex = 0; if (re.test(t.text)) hits.push({ k: '#backtest', section: 'Backtest · ' + s.title, line: t.text }); }); });
    return '<div class="doc"><h1>Recherche : « ' + esc(q) + ' »</h1><p class="muted">' + hits.length + ' résultat(s)' + (hits.length > 200 ? ' (200 premiers)' : '') + '</p></div>' +
      hits.slice(0, 200).map(function (x) {
        var go = x.k.charAt(0) === '#' ? x.k : '#doc/' + x.k + '#' + slug(x.section);
        return '<div class="hit" data-go="' + esc(go) + '"><b>' + esc(title[x.k] || 'Backtest') + '</b> · <span class="muted">' + esc(x.section) + '</span><br>' + esc(x.line.replace(/^[#>\-*\s|]+/, '').slice(0, 260)).replace(new RegExp('(' + q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig'), '<mark>$1</mark>') + '</div>';
      }).join('');
  }

  // --- Export / import / rapport ---
  function download(name, text, type) { var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([text], { type: type })); a.download = name; document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500); }
  function report() {
    var day = new Date().toLocaleDateString('fr-FR'), out = ['ROADLINE · avancement ' + D.version + ' · ' + day, ''];
    var part = function (label, groups, prefix, textOf) {
      out.push('=== ' + label);
      groups.forEach(function (g, gi) { out.push('', g.title); (g.items || g.tests).forEach(function (it, ii) { var id = prefix + ':' + gi + ':' + ii; out.push((state.checks[id] ? '[x] ' : '[ ] ') + textOf(it) + (state.notes[id] ? '\n      note : ' + state.notes[id] : '')); }); });
      out.push('');
    };
    part('PRIORITÉS', D.priorities, 'pr', function (t) { return t; });
    part('BACKTEST', D.backtest, 'bt', function (t) { return t.text; });
    return out.join('\n');
  }
  document.addEventListener('click', function (e) {
    var t = e.target.closest('[data-act],[data-go]'); if (!t) return;
    if (t.dataset.go) { location.hash = t.dataset.go; return; }
    var a = t.dataset.act;
    if (a === 'print') window.print();
    else if (a === 'export') download('roadline-avancement-' + new Date().toISOString().slice(0, 10) + '.json', JSON.stringify({ version: D.version, state: state }, null, 1), 'application/json');
    else if (a === 'report') download('roadline-rapport-' + new Date().toISOString().slice(0, 10) + '.txt', report(), 'text/plain');
    else if (a === 'md') download(t.dataset.key + '.md', D.docs[t.dataset.key], 'text/markdown');
    else if (a === 'reset') { if (confirm('Tout décocher et effacer les notes ?')) { state = { checks: {}, notes: {} }; save(); render(); } }
    else if (a === 'import') {
      var inp = document.createElement('input'); inp.type = 'file'; inp.accept = '.json,application/json';
      inp.onchange = function () { var f = inp.files[0]; if (!f) return; var r = new FileReader(); r.onload = function () { try { var d = JSON.parse(r.result); if (!d.state || !d.state.checks) throw 0; state = d.state; save(); render(); alert('Avancement importé.'); } catch (x) { alert('Fichier non reconnu.'); } }; r.readAsText(f); };
      inp.click();
    }
  });
  document.addEventListener('change', function (e) {
    var id = e.target.dataset && e.target.dataset.id; if (!id) return;
    state.checks[id] = e.target.checked; save();
    var it = e.target.closest('.item'); if (it) it.classList.toggle('done', e.target.checked);
  });
  document.addEventListener('input', function (e) { var id = e.target.dataset && e.target.dataset.note; if (id === undefined) return; if (e.target.value) state.notes[id] = e.target.value; else delete state.notes[id]; save(); });
  var timer; $('#q').addEventListener('input', function () { clearTimeout(timer); var v = this.value; timer = setTimeout(function () { location.hash = v.trim() ? 'search/' + encodeURIComponent(v) : 'accueil'; }, 250); });
  $('#menuBtn').addEventListener('click', function () { $('#nav').classList.toggle('open'); });
  $('#theme').addEventListener('click', function () {
    var dark = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim() === '#0f1115';
    document.documentElement.dataset.theme = dark ? 'light' : 'dark'; try { localStorage.setItem(KEY + '-theme', document.documentElement.dataset.theme); } catch (x) {}
  });
  window.addEventListener('hashchange', function () {
    render();
    var anchor = location.hash.split('#')[2]; if (anchor) { var el = document.getElementById(anchor); if (el) el.scrollIntoView(); }
  });
  navHtml(); render();
})();
</script>
</body>
</html>
'''

if __name__ == '__main__':
    data, missing = build()
    n = sum(len(s['tests']) for s in data['backtest'])
    print(f"docs/hub/index.html : {len(data['docs'])} documents, {n} tests de backtest, {sum(len(p['items']) for p in data['priorities'])} priorités, {len(data['pdfs'])} PDF")
    if missing:
        print('Absents (ignorés) : ' + ', '.join(missing))
        sys.exit(1)
