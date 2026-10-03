-- Niveau staff partagé avec le client (aide des touches, filtre des commandes) et commandes serveur masquées aux joueurs.
local function staffLevel(src)
    local ok, lvl = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
    return ok and tonumber(lvl) or 0
end

--- Masque, pour un joueur non staff, les suggestions des commandes serveur qui ne lui servent pas.
local function filterFor(src)
    local lvl = staffLevel(src)
    Player(src).state:set('gsStaff', lvl > 0, true)
    if lvl > 0 then return end
    for _, c in ipairs(GetRegisteredCommands()) do
        if not PlayerCommands[c.name] then TriggerClientEvent('chat:removeSuggestion', src, '/' .. c.name) end
    end
end

RegisterNetEvent('gs_onboarding:server:commands', function()
    local src = source
    if exports.gs_security:RateLimit(src, 'gs_onboarding:commands', 3, 30000) then filterFor(src) end
end)

-- Le chat redonne toutes les suggestions quand une ressource (re)démarre : on refiltre juste après.
AddEventHandler('onServerResourceStart', function()
    SetTimeout(3000, function()
        for _, s in ipairs(GetPlayers()) do filterFor(tonumber(s)) end
    end)
end)
