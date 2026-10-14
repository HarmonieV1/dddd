-- gs_radio (client) · V12.51 Portées de la voix de proximité (Config.VoiceRanges), posées par l'export officiel de pma-voice.
-- La portée en cours est corrigée tout de suite (sinon seulement au prochain changement avec ²). Aucune boucle.
local RANGES = Config.VoiceRanges

local function apply()
    if not RANGES or GetResourceState('pma-voice') ~= 'started' then return end
    for name, distance in pairs(RANGES) do
        pcall(function() exports['pma-voice']:addVoiceMode(distance + 0.0, name) end) -- [API] pma-voice : nom existant = portée remplacée
    end
    local st = LocalPlayer.state.proximity -- [API] pma-voice : { index, distance, mode }
    local d = st and RANGES[st.mode]
    if d and st.distance ~= d then
        MumbleSetTalkerProximity(d + 0.0)
        LocalPlayer.state:set('proximity', { index = st.index, distance = d, mode = st.mode }, true)
    end
end

AddEventHandler('onClientResourceStart', function(res)
    if res == 'pma-voice' or res == GetCurrentResourceName() then SetTimeout(1500, apply) end
end)
AddEventHandler('mumbleConnected', function() SetTimeout(1000, apply) end) -- connexion / reconnexion au vocal
