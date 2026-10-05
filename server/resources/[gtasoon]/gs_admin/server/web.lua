-- gs_admin (serveur) · V10.1 « Panneau staff mobile ». Petite page web servie par le serveur FiveM lui-même :
--   http://ADRESSE-DU-SERVEUR:30120/gs_admin/   (ou l'adresse https « …users.cfx.re » du serveur, + /gs_admin/)
-- Sur le téléphone : ouvrir l'adresse, « Ajouter à l'écran d'accueil » = une appli. Codes d'accès dans secrets.cfg :
--   set gs_admin_web "Pseudo1:code-long-1,Pseudo2:code-long-2"     (vide = panneau désactivé)
-- Actions : joueurs en ville, geler / dégeler, avertir, message, expulser, annonce (même code que le bot Discord,
-- journalisées « Web · Pseudo »). Trop d'essais ratés depuis une même adresse = blocage 15 min.
local Web = { fails = {} } -- [ip] = { n, until }

local function codes()
    local out = {}
    for entry in GetConvar('gs_admin_web', ''):gmatch('[^,]+') do
        local name, code = entry:match('^%s*([^:]+):(.-)%s*$')
        if name and code and #code >= 12 then out[code] = name end -- code trop court = ignoré (sécurité)
    end
    return out
end

local function ipOf(req) return tostring(req.address or '?'):gsub(':%d+$', '') end

function Web.auth(ip, token)
    local f = Web.fails[ip]
    if f and f.untilAt and os.time() < f.untilAt then return nil, 'Trop d\'essais : réessaie dans 15 min.' end
    local who = type(token) == 'string' and codes()[token] or nil
    if not who then
        f = f or { n = 0 }
        f.n = f.n + 1
        if f.n >= 5 then f.n, f.untilAt = 0, os.time() + 900 end
        Web.fails[ip] = f
        return nil, 'Code refusé.'
    end
    Web.fails[ip] = nil
    return who
end

local ACTIONS = { players = true, freeze = true, unfreeze = true, warn = true, message = true, kick = true, announce = true }

function Web.handle(ip, body)
    local ok, d = pcall(json.decode, body or '')
    if not ok or type(d) ~= 'table' then return { ok = false, text = 'Requête invalide.' } end
    local who, err = Web.auth(ip, d.token)
    if not who then return { ok = false, text = err, auth = false } end
    if d.action == 'login' then return { ok = true, text = 'Bonjour ' .. who .. '.', who = who } end
    if not ACTIONS[d.action] then return { ok = false, text = 'Action inconnue.' } end
    local good, text = Admin.remote(d.action, d.id, d.text, 'Web · ' .. who)
    return { ok = good == true, text = text or '' }
end

local PAGE = [[<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#140a24"><meta name="apple-mobile-web-app-capable" content="yes"><title>RoadLine Staff</title>
<style>:root{--bg:#140a24;--card:#22123a;--txt:#f2ecff;--mut:#a99bc4;--acc:#b048ff;--ok:#5aff8c;--ko:#ff5470}
*{box-sizing:border-box}body{margin:0;font:16px system-ui,sans-serif;background:var(--bg);color:var(--txt);padding:16px;max-width:560px;margin:auto}
h1{font-size:20px;margin:4px 0 14px}h1 b{color:var(--acc)}.card{background:var(--card);border-radius:14px;padding:14px;margin-bottom:12px}
input,textarea{width:100%;padding:12px;border-radius:10px;border:1px solid #3a2560;background:#1a0d2e;color:var(--txt);font-size:16px;margin:6px 0}
button{padding:12px 14px;border:0;border-radius:10px;background:var(--acc);color:#fff;font-weight:600;font-size:15px;margin:4px 4px 0 0}
button.g{background:#3a2560}button.r{background:var(--ko)}#out{white-space:pre-wrap;font-family:ui-monospace,monospace;font-size:14px;color:var(--mut)}
.ok{color:var(--ok)!important}.ko{color:var(--ko)!important}.row{display:flex;gap:6px}.row input{flex:1}.hide{display:none}small{color:var(--mut)}</style></head>
<body><h1><b>RoadLine</b> · Staff</h1>
<div class="card" id="login"><small>Code d'accès (donné par l'administrateur)</small><input id="code" type="password" autocomplete="current-password">
<button onclick="login()">Entrer</button></div>
<div id="app" class="hide">
<div class="card"><button onclick="act('players')">👥 Joueurs en ville</button><button class="g" onclick="logout()">Quitter</button></div>
<div class="card"><small>Joueur (identifiant en ville, voir la liste)</small><input id="id" type="number" inputmode="numeric" placeholder="ex : 12">
<small>Motif / message</small><textarea id="txt" rows="2" maxlength="200"></textarea>
<button onclick="act('freeze')">🧊 Geler</button><button class="g" onclick="act('unfreeze')">Dégeler</button><button class="g" onclick="act('message')">✉️ Message</button>
<button class="g" onclick="act('warn')">⚠️ Avertir</button><button class="r" onclick="if(confirm('Expulser ce joueur ?'))act('kick')">Expulser</button></div>
<div class="card"><small>Annonce à toute la ville</small><div class="row"><input id="ann" maxlength="200"><button onclick="act('announce',true)">📢</button></div></div>
<div class="card"><div id="out">…</div></div><small>Bannir : panel txAdmin (bannissements durables, même sur téléphone).</small></div>
<script>let T=sessionStorage.getItem('t')||'';const $=i=>document.getElementById(i);
async function call(b){try{const r=await fetch('api',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(Object.assign({token:T},b))});return await r.json()}catch(e){return{ok:false,text:'Serveur injoignable.'}}}
function show(r){const o=$('out');o.textContent=r.text;o.className=r.ok?'ok':'ko';if(r.auth===false)logout()}
async function login(){T=$('code').value.trim();const r=await call({action:'login'});if(r.ok){sessionStorage.setItem('t',T);$('login').classList.add('hide');$('app').classList.remove('hide');act('players')}else{alert(r.text)}}
function logout(){T='';sessionStorage.removeItem('t');$('app').classList.add('hide');$('login').classList.remove('hide')}
async function act(a,ann){show(await call({action:a,id:parseInt($('id').value)||0,text:ann?$('ann').value:$('txt').value}))}
if(T){call({action:'login'}).then(r=>{if(r.ok){$('login').classList.add('hide');$('app').classList.remove('hide');act('players')}})}</script></body></html>]]

SetHttpHandler(function(req, res)
    local headers = { ['Content-Type'] = 'text/html; charset=utf-8', ['Cache-Control'] = 'no-store', ['X-Frame-Options'] = 'DENY' }
    if req.method == 'POST' and req.path == '/api' then
        req.setDataHandler(function(body)
            local out = Web.handle(ipOf(req), body)
            res.writeHead(200, { ['Content-Type'] = 'application/json', ['Cache-Control'] = 'no-store' })
            res.send(json.encode(out))
        end)
        return
    end
    if req.path == '/' or req.path == '' or req.path == '/index.html' then
        if next(codes()) == nil then
            res.writeHead(404, headers)
            return res.send('Panneau staff désactivé (gs_admin_web vide dans secrets.cfg).')
        end
        res.writeHead(200, headers)
        return res.send(PAGE)
    end
    res.writeHead(404, headers)
    res.send('Introuvable.')
end)

AdminWeb = Web
