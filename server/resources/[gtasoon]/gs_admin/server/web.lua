-- gs_admin (serveur) · V10.1 « Panneau staff mobile » (V11 : onglets Joueurs / Tickets / Ville, cartes cliquables, rafraîchi toutes les 10 s). Petite page web servie par le serveur FiveM lui-même :
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

local function ipOf(req)
    local ip = tostring(req.address or '?'):gsub(':%d+$', '')
    -- V11 : derrière l'adresse https (Caddy sur le VPS), la vraie adresse est dans X-Forwarded-For (sinon tout le monde = 127.0.0.1)
    if ip == '127.0.0.1' or ip == '::1' or ip == '[::1]' then
        local h = req.headers or {}
        local fwd = h['X-Forwarded-For'] or h['x-forwarded-for']
        if type(fwd) == 'string' and fwd ~= '' then ip = fwd:match('^%s*([^,%s]+)') or ip end
    end
    return ip
end

-- V11 : appli installable (PWA) — « Installer » / « Sur l'écran d'accueil » depuis le navigateur du téléphone (https conseillé)
local MANIFEST = json.encode({ name = 'RoadLine Staff', short_name = 'RL Staff', start_url = './', scope = './', display = 'standalone',
    background_color = '#140a24', theme_color = '#140a24', lang = 'fr',
    icons = { { src = 'icon-192.png', sizes = '192x192', type = 'image/png' }, { src = 'icon-512.png', sizes = '512x512', type = 'image/png', purpose = 'any maskable' } } })
local SW = "self.addEventListener('install',e=>self.skipWaiting());self.addEventListener('activate',e=>self.clients.claim());"
    .. "self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;e.respondWith(fetch(e.request).catch(()=>new Response("
    .. "'<meta charset=utf-8><body style=\"background:#140a24;color:#f2ecff;font:16px system-ui;padding:24px\">Serveur injoignable : réessaie dans un instant.',"
    .. "{headers:{'Content-Type':'text/html; charset=utf-8'}})))});"

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

local ACTIONS = { players = true, freeze = true, unfreeze = true, warn = true, message = true, kick = true, announce = true, jail = true, unjail = true, revive = true } -- V12.3 : isolement, réanimation

function Web.handle(ip, body)
    local ok, d = pcall(json.decode, body or '')
    if not ok or type(d) ~= 'table' then return { ok = false, text = 'Requête invalide.' } end
    local who, err = Web.auth(ip, d.token)
    if not who then return { ok = false, text = err, auth = false } end
    if d.action == 'login' then return { ok = true, text = 'Bonjour ' .. who .. '.', who = who } end
    if d.action == 'overview' then return { ok = true, data = Admin.overview(), txadmin = GetConvar('gs_admin_txadmin', '') } end
    if not ACTIONS[d.action] then return { ok = false, text = 'Action inconnue.' } end
    local good, text = Admin.remote(d.action, d.id, d.text, 'Web · ' .. who, d.minutes)
    return { ok = good == true, text = text or '' }
end

local PAGE = [[<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#140a24"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="mobile-web-app-capable" content="yes"><title>RoadLine Staff</title>
<link rel="manifest" href="manifest.webmanifest"><link rel="icon" href="icon-192.png"><link rel="apple-touch-icon" href="icon-192.png"><meta name="apple-mobile-web-app-title" content="RL Staff">
<style>:root{--bg:#140a24;--card:#22123a;--line:#3a2560;--txt:#f2ecff;--mut:#a99bc4;--acc:#b048ff;--ok:#5aff8c;--ko:#ff5470;--warn:#ffc04d}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}body{margin:0;font:16px system-ui,sans-serif;background:var(--bg);color:var(--txt);padding:16px 16px 90px;max-width:620px;margin:auto}
h1{font-size:20px;margin:4px 0 4px}h1 b{color:var(--acc)}#stat{color:var(--mut);font-size:13px;margin-bottom:12px}.card{background:var(--card);border-radius:14px;padding:14px;margin-bottom:12px}
input,textarea{width:100%;padding:12px;border-radius:10px;border:1px solid var(--line);background:#1a0d2e;color:var(--txt);font-size:16px;margin:6px 0}
button{padding:12px 14px;border:0;border-radius:10px;background:var(--acc);color:#fff;font-weight:600;font-size:15px;margin:4px 4px 0 0;min-height:44px}
button.g{background:var(--line)}button.r{background:var(--ko)}.hide{display:none!important}small{color:var(--mut)}
.p{display:flex;justify-content:space-between;align-items:center;padding:12px;border-radius:12px;background:#1a0d2e;margin:6px 0;cursor:pointer;border:1px solid transparent}
.p.sel{border-color:var(--acc)}.p b{font-size:15px}.p span{color:var(--mut);font-size:13px}.tag{font-size:12px;padding:2px 8px;border-radius:99px;background:var(--line);color:var(--txt)}
.tag.f{background:#2a4d7a}.tag.w{background:#6b4a10}#toast{position:fixed;left:16px;right:16px;bottom:78px;max-width:588px;margin:auto;padding:12px 14px;border-radius:12px;background:#0d061a;border:1px solid var(--line);font-size:14px}
#toast.ok{border-color:var(--ok)}#toast.ko{border-color:var(--ko)}nav{position:fixed;left:0;right:0;bottom:0;display:flex;background:#0d061a;border-top:1px solid var(--line);padding-bottom:env(safe-area-inset-bottom)}
nav button{flex:1;margin:0;border-radius:0;background:none;color:var(--mut);font-size:13px;padding:10px 4px}nav button.on{color:var(--acc)}.row{display:flex;gap:6px}.row input{flex:1}#who{font-weight:600;margin-bottom:4px}</style></head>
<body><h1><b>RoadLine</b> · Staff</h1><div id="stat"></div>
<div class="card" id="login"><small>Code d'accès (donné par l'administrateur)</small><input id="code" type="password" autocomplete="current-password">
<button onclick="login()">Entrer</button></div>
<div id="app" class="hide">
<section id="t-players"><div class="card"><input id="q" placeholder="Rechercher (pseudo, personnage, n°)" oninput="draw()"><div id="plist"></div></div>
<div class="card hide" id="sheet"><div id="who"></div><small>Motif / message (obligatoire pour avertir et expulser)</small><textarea id="txt" rows="2" maxlength="200"></textarea>
<button onclick="act('freeze')">🧊 Geler</button><button class="g" onclick="act('unfreeze')">Dégeler</button><button class="g" onclick="act('message')">✉️ Message</button>
<button class="g" onclick="act('warn')">⚠️ Avertir</button><button class="r" onclick="if(confirm('Expulser ce joueur ?'))act('kick')">Expulser</button>
<div class="row" style="margin-top:8px"><input id="min" type="number" min="1" max="240" value="15" placeholder="min"><button class="r" onclick="if(confirm('Isoler ce joueur ?'))act('jail')">⛓️ Isoler</button><button class="g" onclick="act('unjail')">Libérer</button><button class="g" onclick="act('revive')">❤️ Réanimer</button></div></div></section>
<section id="t-tickets" class="hide"><div class="card"><div id="tlist"></div></div></section>
<section id="t-city" class="hide"><div class="card"><small>Annonce à toute la ville</small><div class="row"><input id="ann" maxlength="200"><button onclick="annonce()">📢</button></div></div>
<div class="card"><small>Bannissements durables, console, redémarrages programmés</small><div id="tx"></div></div>
<div class="card"><button class="g" onclick="logout()">Se déconnecter</button></div></section>
</div><div id="toast" class="hide"></div>
<nav id="nav" class="hide"><button class="on" onclick="tab('players',this)">👥 Joueurs</button><button onclick="tab('tickets',this)">🎫 Tickets <span id="tc"></span></button><button onclick="tab('city',this)">🏙️ Ville</button></nav>
<script>let T=sessionStorage.getItem('t')||'',D=null,SEL=0,timer=null;const $=i=>document.getElementById(i);
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function call(b){try{const r=await fetch('api',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(Object.assign({token:T},b))});return await r.json()}catch(e){return{ok:false,text:'Serveur injoignable.'}}}
function toast(r){const o=$('toast');o.textContent=r.text;o.className=r.ok?'ok':'ko';clearTimeout(o._t);o._t=setTimeout(()=>o.className='hide',4000);if(r.auth===false)logout()}
const dur=s=>s<3600?Math.floor(s/60)+' min':Math.floor(s/3600)+' h '+Math.floor(s%3600/60)+' min';
async function refresh(){const r=await call({action:'overview'});if(!r.ok){if(r.auth===false)logout();return}D=r.data;
$('stat').textContent=D.players.length+'/'+D.max+' en ville · '+D.staffOnDuty+' staff en service · '+D.version+' · en ligne depuis '+dur(D.uptime);
$('tc').textContent=D.tickets.length?'('+D.tickets.length+')':'';$('tx').innerHTML=r.txadmin?'<a href="'+esc(r.txadmin)+'" target="_blank"><button>Ouvrir txAdmin</button></a>':'<small>txAdmin : non configuré (gs_admin_txadmin).</small>';draw()}
function draw(){if(!D)return;const q=$('q').value.toLowerCase();$('plist').innerHTML=D.players.filter(p=>!q||(p.id+' '+p.name+' '+p.char).toLowerCase().includes(q)).map(p=>
'<div class="p'+(p.id==SEL?' sel':'')+'" onclick="pick('+p.id+')"><div><b>'+p.id+' · '+esc(p.name)+'</b><br><span>'+esc(p.char||'—')+'</span></div><div>'+(p.frozen?'<span class="tag f">gelé</span> ':'')+'<span class="tag">'+p.ping+' ms</span></div></div>').join('')||'<small>Personne en ville.</small>';
$('tlist').innerHTML=D.tickets.map(t=>'<div class="p" onclick="pick('+t.src+',true)"><div><b>#'+t.id+' · '+esc(t.name)+'</b><br><span>'+esc(t.message)+'</span></div><div><span class="tag'+(t.claimedBy?'':' w')+'">'+(t.claimedBy?'pris':'il y a '+dur(t.age))+'</span></div></div>').join('')||'<small>Aucun ticket ouvert.</small>';
if(SEL&&!D.players.some(p=>p.id==SEL)){SEL=0;$('sheet').classList.add('hide')}}
function pick(id,fromTicket){SEL=id;const p=D.players.find(x=>x.id==id);if(!p){toast({ok:false,text:'Ce joueur n\'est plus en ville.'});return}
$('who').textContent=p.id+' · '+p.name+(p.char?' ('+p.char+')':'');$('sheet').classList.remove('hide');if(fromTicket)tab('players',document.querySelector('nav button'));draw();$('sheet').scrollIntoView({behavior:'smooth'})}
function tab(n,b){for(const s of ['players','tickets','city'])$('t-'+s).classList.toggle('hide',s!==n);document.querySelectorAll('nav button').forEach(x=>x.classList.toggle('on',x===b))}
async function act(a){if(!SEL)return;toast(await call({action:a,id:SEL,text:$('txt').value,minutes:+$('min').value||15}));refresh()}
async function annonce(){toast(await call({action:'announce',text:$('ann').value}));$('ann').value=''}
function enter(){$('login').classList.add('hide');$('app').classList.remove('hide');$('nav').classList.remove('hide');refresh();clearInterval(timer);timer=setInterval(()=>{if(!document.hidden)refresh()},10000)}
async function login(){T=$('code').value.trim();const r=await call({action:'login'});if(r.ok){sessionStorage.setItem('t',T);enter()}else{alert(r.text)}}
function logout(){T='';sessionStorage.removeItem('t');clearInterval(timer);$('app').classList.add('hide');$('nav').classList.add('hide');$('login').classList.remove('hide');$('stat').textContent=''}
if(T){call({action:'login'}).then(r=>{if(r.ok)enter()})}
if('serviceWorker' in navigator&&location.protocol==='https:')navigator.serviceWorker.register('sw.js').catch(()=>{});</script></body></html>]]

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
    if req.path == '/manifest.webmanifest' then
        res.writeHead(200, { ['Content-Type'] = 'application/manifest+json' })
        return res.send(MANIFEST)
    end
    if req.path == '/sw.js' then
        res.writeHead(200, { ['Content-Type'] = 'text/javascript', ['Cache-Control'] = 'no-cache', ['Service-Worker-Allowed'] = './' })
        return res.send(SW)
    end
    if req.path == '/icon-192.png' or req.path == '/icon-512.png' then
        local png = LoadResourceFile(GetCurrentResourceName(), 'web/pwa' .. req.path)
        if png then
            res.writeHead(200, { ['Content-Type'] = 'image/png', ['Cache-Control'] = 'max-age=86400' })
            return res.send(png)
        end
    end
    if req.path == '/' or req.path == '' or req.path == '/index.html' then
        if next(codes()) == nil then
            res.writeHead(404, headers)
            return res.send('Panneau staff désactivé : aucun code d\'accès. Sur le PC : GERER-OVH.bat → « Codes du panneau staff ».')
        end
        res.writeHead(200, headers)
        return res.send(PAGE)
    end
    res.writeHead(404, headers)
    res.send('Introuvable.')
end)

AdminWeb = Web
