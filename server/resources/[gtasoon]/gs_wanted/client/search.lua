-- gs_wanted (client) : police IA « maligne ». Quand on sème les policiers du jeu, ils fouillent la dernière zone connue pendant
-- quelques minutes : y retourner (ou y rester) relance la recherche. Une seule boucle, active seulement si on a été recherché.
local S = Config.NpcPolice.search
local npcMode, heat = false, 0
local lastKnown, wasWanted, searching = nil, false, false

AddEventHandler('gs_wanted:client:npcPolice', function() npcMode = true end) -- s'ajoute à l'écouteur de main.lua (event réseau déjà déclaré)
AddEventHandler('gs_wanted:client:heatChanged', function(h) heat = h end)

local function search(center)
    if searching then return end
    searching = true
    local area = AddBlipForRadius(center.x, center.y, center.z, S.radius)
    SetBlipColour(area, 5) SetBlipAlpha(area, 80)
    lib.notify({ title = 'Police de Los Santos', description = 'Ils fouillent le secteur où ils t\'ont perdu. Éloigne-toi !', type = 'warning', icon = 'magnifying-glass-location', duration = 8000 })
    CreateThread(function()
        local untilAt = GetGameTimer() + S.seconds * 1000
        local told = false
        while GetGameTimer() < untilAt and npcMode do
            if #(GetEntityCoords(cache.ped) - center) < S.radius and GetPlayerWantedLevel(PlayerId()) == 0 and heat > 0 then
                TriggerEvent('gs_wanted:client:npcPolice', 1) -- relance une étoile (recherche reprise dans le secteur)
                told = true
            end
            Wait(3000)
        end
        RemoveBlip(area)
        searching = false
        if not told then lib.notify({ description = 'Les policiers abandonnent leurs recherches.', type = 'success' }) end
    end)
end

CreateThread(function()
    while true do
        if GetPlayerWantedLevel(PlayerId()) > 0 then
            lastKnown, wasWanted = GetEntityCoords(cache.ped), true
            Wait(2000)
        else
            if wasWanted and npcMode and lastKnown then
                wasWanted = false
                search(lastKnown)
            end
            wasWanted = false
            Wait(searching and 3000 or 5000)
        end
    end
end)
