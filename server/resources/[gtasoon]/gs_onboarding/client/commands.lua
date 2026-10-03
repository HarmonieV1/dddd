-- Masque les suggestions des commandes client inutiles aux joueurs (touches, outils staff). Le serveur fait de même
-- pour les siennes (server/commands.lua) et pose LocalPlayer.state.gsStaff.
local function filter()
    TriggerServerEvent('gs_onboarding:server:commands')
    Wait(1500)
    if LocalPlayer.state.gsStaff then return end
    for _, c in ipairs(GetRegisteredCommands()) do
        if not PlayerCommands[c.name] then TriggerEvent('chat:removeSuggestion', '/' .. c.name) end
    end
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function() SetTimeout(4000, filter) end) -- [API] qbx_core
AddEventHandler('onClientResourceStart', function() SetTimeout(3000, function() if LocalPlayer.state.isLoggedIn then filter() end end) end)
