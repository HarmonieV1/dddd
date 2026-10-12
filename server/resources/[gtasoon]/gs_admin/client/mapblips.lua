-- gs_admin (client) · V12.29 : blips PUBLICS des mappings (tous les joueurs, pas seulement le staff). La liste vient du
-- serveur (server/maps.js : lieu lu dans les fichiers de chaque map, nom et icône choisis) ; elle se met à jour toute seule
-- si une map est arrêtée. Visibles de près (« courte portée ») pour ne pas surcharger la carte.
local blips = {}

RegisterNetEvent('gs_admin:mapBlips', function(list)
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    if type(list) ~= 'table' then return end
    for _, p in ipairs(list) do
        local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
        if x and y and z and type(p.label) == 'string' then
            local b = AddBlipForCoord(x + 0.0, y + 0.0, z + 0.0)
            SetBlipSprite(b, math.floor(tonumber(p.sprite) or 1))
            SetBlipColour(b, math.floor(tonumber(p.color) or 0))
            SetBlipScale(b, 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(p.label:sub(1, 40))
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end)

CreateThread(function()
    Wait(8000)
    TriggerServerEvent('gs_admin:mapBlips:get')
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('gs_admin:mapBlips:get') end) -- [API]

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)
