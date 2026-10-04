-- gs_lsradio (serveur) · V10 « Radio Los Santos ». File d'interventions alimentée par les vrais événements de la ville,
-- une à la fois (Config.Gap), diffusée à tous ; seuls ceux qui roulent radio allumée l'entendent (client).
local L = Config.Lines

LSRadio = { queue = {}, last = 0, lastChatter = 0, tip = 0 }

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end

function LSRadio.say(text)
    if type(text) ~= 'string' or text == '' then return end
    if #LSRadio.queue >= 6 then table.remove(LSRadio.queue, 1) end -- l'actualité la plus fraîche d'abord
    LSRadio.queue[#LSRadio.queue + 1] = text
end

function LSRadio.tick()
    if now() - LSRadio.last < Config.Gap then return nil end
    local text = table.remove(LSRadio.queue, 1)
    if not text and now() - LSRadio.lastChatter >= Config.Chatter * 60 then
        LSRadio.lastChatter = now()
        LSRadio.tip = LSRadio.tip % #Config.Tips + 1
        local h = started('gs_weather') and select(2, pcall(function() return exports.gs_weather:GetGameTime() end))
        local w = (GlobalState.gsWeather or {}).type
        local WEATHER = { CLEAR = 'grand ciel bleu', EXTRASUNNY = 'plein soleil', CLOUDS = 'quelques nuages', OVERCAST = 'ciel couvert',
            RAIN = 'de la pluie', THUNDER = 'de l\'orage', FOGGY = 'du brouillard', SMOG = 'un peu de brume', CLEARING = 'des éclaircies' }
        text = L.chatter:format(type(h) == 'number' and ('%dh'):format(h) or 'l\'heure de sortir', WEATHER[w or ''] or 'temps clément', Config.Tips[LSRadio.tip])
    end
    if not text then return nil end
    LSRadio.last = now()
    TriggerClientEvent('gs_lsradio:client:say', -1, Config.Host, text)
    return text
end

AddEventHandler('gs_events:server:remind', function(label, desc, ahead)
    LSRadio.say(ahead > 0 and L.remind:format(label, ahead, desc) or L.start:format(label, desc))
end)
AddEventHandler('gs_wanted:server:fugitive', function(title, bounty) LSRadio.say(L.fugitive:format(title, bounty or 0)) end)
AddEventHandler('gs_faitsdivers:server:new', function(label, zone) LSRadio.say(L.faitdivers:format(label:lower(), zone)) end)
AddEventHandler('gs_weather:server:eventStarted', function(id) if id == 'storm' then LSRadio.say(L.storm) end end)

local ringSaid = 0
CreateThread(function()
    while true do
        Wait(15000)
        if started('gs_fightclub') and now() - ringSaid > 3 * 3600 then
            local ok, open = pcall(function() return exports.gs_fightclub:IsOpen() end)
            if ok and open then ringSaid = now() LSRadio.say(L.ring) end
        end
        LSRadio.tick()
    end
end)

exports('Say', LSRadio.say)
