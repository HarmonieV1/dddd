-- gs_discord (serveur) · V9. Statut en direct (un message de webhook édité en place), annonces, rôles de métier.
-- Les URL et le jeton restent côté serveur (convars `set`, jamais envoyés aux joueurs ni affichés en console).
local Bridge = exports.gs_bridge

Discord = { started = os.time(), roleCache = {} } -- roleCache[src] = job déjà synchronisé

local API = 'https://discord.com/api/v10'
local function conv(name) return GetConvar(name, '') end
local function validHook(url) return type(url) == 'string' and url:match('^https://discord%.com/api/webhooks/%d+/[%w_%-]+$') ~= nil
    or (type(url) == 'string' and url:match('^https://discordapp%.com/api/webhooks/%d+/[%w_%-]+$') ~= nil) end

local function started(res) return GetResourceState(res) == 'started' end

-- V10.1 : rôles de métier aussi lus dans secrets.cfg (jamais écrasé par une mise à jour) :
--   set gs_discord_roles "police=123456789012345678,ambulance=234567890123456789"
for job, role in GetConvar('gs_discord_roles', ''):gmatch('([%w_]+)%s*=%s*(%d+)') do Config.Roles[job] = role end

local function onDuty(job)
    if not started('gs_jobs') then return 0 end
    local ok, l = pcall(function() return exports.gs_jobs:GetOnDutyPlayers(job) end)
    return ok and #(l or {}) or 0
end

local function duration(s)
    local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
    return h > 0 and ('%d h %02d'):format(h, m) or ('%d min'):format(m)
end

--- Contenu de l'embed de statut
function Discord.statusEmbed()
    local players, max = #GetPlayers(), GetConvarInt('sv_maxclients', 48)
    local fields = {
        { name = '👥 En ville', value = ('**%d** / %d'):format(players, max), inline = true },
        { name = '⏱️ En ligne depuis', value = duration(os.time() - Discord.started), inline = true },
        { name = '📦 Version', value = GetConvar('gs_public_version', 'V4 · bêta'), inline = true },
    }
    local svc = {}
    for _, s in ipairs(Config.Services) do svc[#svc + 1] = ('%s : **%d**'):format(s.label, onDuty(s.job)) end
    fields[#fields + 1] = { name = 'En service', value = table.concat(svc, '\n'), inline = true }
    if started('gs_weather') then
        local ok, w = pcall(function() return exports.gs_weather:GetWeather() end)
        local okT, h, m = pcall(function() return exports.gs_weather:GetGameTime() end)
        fields[#fields + 1] = { name = '🌤️ Los Santos', value = ('%s · %s'):format(ok and tostring(w or '?') or '?', okT and h and ('%02dh%02d'):format(h, m or 0) or '?'), inline = true }
    end
    local connect = conv('gs_connect')
    return {
        title = ('🟢 %s · Serveur en ligne'):format(Config.Name),
        description = connect ~= '' and ('Rejoindre : **%s**'):format(connect) or 'F8 → `connect` avec l\'adresse du serveur',
        color = Config.Color, fields = fields,
        footer = { text = 'Mis à jour' }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
end

local function post(url, payload, cb)
    PerformHttpRequest(url, function(code, body) if cb then cb(code, body) end end, payload.method or 'POST',
        json.encode(payload.data), { ['Content-Type'] = 'application/json' })
end

--- V12.59 · « Le bot n'envoie pas toujours les infos du serveur » : un échec de mise à jour du #statut était silencieux.
--- Il est écrit une fois dans la console (et de nouveau seulement si l'erreur change), avec la cause probable.
local lastStatusCode = 200
function Discord.statusFailed(code)
    code = tonumber(code) or 0
    if code >= 200 and code < 300 then lastStatusCode = 200 return end
    if code == lastStatusCode then return end
    lastStatusCode = code
    local why = code == 404 and 'message ou webhook #statut supprimé : recréé au prochain passage (sinon relance CONFIGURER-DISCORD.bat)'
        or code == 429 and 'Discord limite les envois : réessai dans une minute'
        or (code == 401 or code == 403) and 'webhook #statut refusé : recrée-le dans Discord puis CONFIGURER-DISCORD.bat'
        or code == 0 and 'pas de réponse de Discord (réseau du serveur)'
        or 'réessai dans une minute'
    print(('^3[gs_discord] Statut Discord non mis à jour (code %d) : %s.^0'):format(code, why))
end

--- Met à jour le message de statut (le crée la première fois et retient son identifiant)
function Discord.status()
    local hook = conv('gs_webhook_status')
    if not validHook(hook) then return false end
    local embed = Discord.statusEmbed()
    local id = GetResourceKvpString('statusMsg')
    if id and id ~= '' then
        -- V12.59 : l'édition d'un message de webhook n'accepte pas `username` (envoyé seulement à la création)
        post(hook .. '/messages/' .. id, { method = 'PATCH', data = { embeds = { embed }, allowed_mentions = { parse = {} } } }, function(code)
            Discord.statusFailed(code)
            if code == 404 then DeleteResourceKvp('statusMsg') end -- message supprimé dans Discord : recréé au prochain passage
        end)
    else
        post(hook .. '?wait=true', { data = { username = Config.Name, embeds = { embed }, allowed_mentions = { parse = {} } } }, function(code, body)
            Discord.statusFailed(code)
            if code == 200 and body then
                local ok, msg = pcall(json.decode, body)
                if ok and msg and msg.id then SetResourceKvp('statusMsg', tostring(msg.id)) end
            end
        end)
    end
    return true
end

--- Annonce publique (salon #annonces). Exportée : `exports.gs_discord:Announce('Titre', 'Texte')`
--- V12.5 : `mention` = 'everyone' | 'here' notifie le salon (utilisé par /annonce du bot, staff uniquement).
function Discord.announce(title, text, color, mention)
    local hook = conv('gs_webhook_annonces')
    if not validHook(hook) then return false end
    local ping = (mention == 'everyone' or mention == 'here') and mention or nil
    post(hook, { data = { username = Config.Name, content = ping and ('@' .. ping) or nil,
        allowed_mentions = { parse = ping and { 'everyone' } or {} },
        embeds = { { title = tostring(title or ''):sub(1, 250), description = tostring(text or ''):sub(1, 2000), color = color or Config.Color,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } } } })
    return true
end

-- Rôles de métier (optionnel) -------------------------------------------------------------------------------
local function discordId(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local d = id:match('^discord:(%d+)$')
        if d then return d end
    end
end

function Discord.syncRoles(src)
    local token, guild = conv('gs_discord_bot_token'), conv('gs_discord_guild')
    if token == '' or not guild:match('^%d+$') or next(Config.Roles) == nil then return false end
    local uid = discordId(src)
    local j = Bridge:GetJob(src)
    if not uid or not j then return false end
    if Discord.roleCache[src] == j.name then return false end
    Discord.roleCache[src] = j.name
    for job, role in pairs(Config.Roles) do
        if tostring(role):match('^%d+$') then
            local url = ('%s/guilds/%s/members/%s/roles/%s'):format(API, guild, uid, role)
            PerformHttpRequest(url, function() end, job == j.name and 'PUT' or 'DELETE', '',
                { ['Authorization'] = 'Bot ' .. token, ['X-Audit-Log-Reason'] = 'RoadLine : metier en jeu' })
        end
    end
    return true
end

AddEventHandler('QBCore:Server:OnJobUpdate', function(src) Discord.roleCache[src] = nil Discord.syncRoles(src) end) -- [API] qbx_core
AddEventHandler('QBCore:Server:PlayerLoaded', function(player) -- [API] qbx_core
    local src = player and player.PlayerData and player.PlayerData.source
    if src then Discord.syncRoles(src) end
end)
AddEventHandler('playerDropped', function() Discord.roleCache[source] = nil end)

-- txAdmin : redémarrages programmés et arrêt -------------------------------------------------------------------
AddEventHandler('txAdmin:events:scheduledRestart', function(e)
    local s = tonumber(e and e.secondsRemaining) or 0
    if s == 900 or s == 300 or s == 60 then
        Discord.announce('🔄 Redémarrage', ('La ville redémarre dans %d min. Mettez-vous à l\'abri !'):format(math.floor(s / 60)), 0xF2C230)
    end
end)
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    local hook = conv('gs_webhook_status')
    local id = GetResourceKvpString('statusMsg')
    if validHook(hook) and id and id ~= '' then
        post(hook .. '/messages/' .. id, { method = 'PATCH', data = { embeds = { { title = ('🔴 %s · Serveur hors ligne'):format(Config.Name),
            description = 'Redémarrage en cours, retour dans quelques minutes.', color = 0xD0122F, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } } } })
    end
end)

exports('Announce', Discord.announce)
exports('StatusEmbed', function() return Discord.statusEmbed() end) -- pour le bot (server/bot.js)
exports('WeeklyText', function()
    if not started('gs_events') then return 'Aucun rendez-vous programmé.' end
    local ok, list = pcall(function() return exports.gs_events:Weekly() end)
    local lines = {}
    for _, w in ipairs(ok and list or {}) do lines[#lines + 1] = ('**%s %s–%s** · %s\n%s'):format(w.dayName, w.from, w.to, w.label, w.desc) end
    return #lines > 0 and table.concat(lines, '\n\n') or 'Aucun rendez-vous programmé.'
end)

CreateThread(function()
    Wait(15000)
    Discord.announce('🟢 La ville est ouverte', ('%s est en ligne. À tout de suite à Los Santos !'):format(Config.Name), 0x5AFF8C)
    while true do
        Discord.status()
        Wait(Config.Every * 1000)
    end
end)
