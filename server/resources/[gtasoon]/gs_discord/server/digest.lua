-- gs_discord (serveur) · V10.2 « Le fil de la ville ». Compte la journée (crimes signalés, arrestations, verdicts, faits
-- divers, rumeurs devenues vraies, légendes) et poste un résumé court chaque soir dans #annonces. Compteurs gardés en
-- KVP (un redémarrage ne remet pas la journée à zéro), remis à zéro après l'envoi.
local D = Config.Digest

Digest = { day = nil, c = {}, legends = {}, rumors = {} }

local function today() return os.date('%Y-%m-%d') end
local function loadDigest()
    local ok, t = pcall(json.decode, GetResourceKvpString('digest') or '{}')
    t = ok and type(t) == 'table' and t or {}
    if t.day == today() then Digest.day, Digest.c, Digest.legends, Digest.rumors = t.day, t.c or {}, t.legends or {}, t.rumors or {}
    else Digest.day, Digest.c, Digest.legends, Digest.rumors = today(), {}, {}, {} end
end
local dirty = false
local function save() SetResourceKvp('digest', json.encode({ day = Digest.day, c = Digest.c, legends = Digest.legends, rumors = Digest.rumors })) dirty = false end
local function inc(k) if Digest.day ~= today() then Digest.day, Digest.c, Digest.legends, Digest.rumors = today(), {}, {}, {} end Digest.c[k] = (Digest.c[k] or 0) + 1 dirty = true end

--- Texte du résumé (nil si la journée a été trop calme pour en parler)
function Digest.text()
    local c, l = Digest.c, {}
    if (c.crimes or 0) > 0 then l[#l + 1] = ('🚨 %d crime(s) signalé(s) à la police'):format(c.crimes) end
    if (c.arrests or 0) > 0 then l[#l + 1] = ('🚔 %d arrestation(s)'):format(c.arrests) end
    if (c.verdicts or 0) > 0 then l[#l + 1] = ('⚖️ %d verdict(s) rendu(s) au tribunal'):format(c.verdicts) end
    if (c.faitsdivers or 0) > 0 then l[#l + 1] = ('🔎 %d fait(s) divers'):format(c.faitsdivers) end
    if #Digest.rumors > 0 then l[#l + 1] = ('🗣️ Une rumeur s\'est réalisée : « %s »'):format(Digest.rumors[#Digest.rumors]:sub(1, 120)) end
    if #Digest.legends > 0 then l[#l + 1] = ('🏆 Nouvelle légende : %s'):format(table.concat(Digest.legends, ', ')) end
    if #l == 0 then return nil end
    if GetResourceState('gs_city') == 'started' then
        local ok, hot = pcall(function() return exports.gs_city:HotDistricts() end)
        if ok and hot and hot[1] then l[#l + 1] = ('🔥 Quartier sous tension ce soir : %s'):format(hot[1]) end
    end
    while #l > 6 do table.remove(l) end
    return table.concat(l, '\n')
end

function Digest.post()
    local text = Digest.text()
    local sent = text ~= nil and Discord.announce('🌙 La nuit à Los Santos', text, 0x2a1440)
    Digest.c, Digest.legends, Digest.rumors = {}, {}, {}
    SetResourceKvp('digest_sent', today())
    save()
    return sent
end

AddEventHandler('gs_wanted:server:reported', function() inc('crimes') end)
AddEventHandler('gs_police:server:jailed', function() inc('arrests') end)
AddEventHandler('gs_justice:server:verdict', function() inc('verdicts') end)
AddEventHandler('gs_faitsdivers:server:new', function() inc('faitsdivers') end)
AddEventHandler('gs_rumors:server:realized', function(text) Digest.rumors[#Digest.rumors + 1] = tostring(text or '') dirty = true end)
AddEventHandler('gs_wanted:server:legend', function(_, name) Digest.legends[#Digest.legends + 1] = tostring(name or '?') dirty = true end)

CreateThread(function()
    loadDigest()
    if not D or not D.enabled then return end
    while true do
        Wait(60000)
        if dirty then save() end
        local t = os.date('*t')
        if t.hour == D.hour and t.min >= D.minute and GetResourceKvpString('digest_sent') ~= today() then Digest.post() end
    end
end)
