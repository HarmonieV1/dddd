-- gs_bridge (client) : état local du joueur pour l'AFFICHAGE uniquement. Le serveur revalide tout.
-- [API] = à vérifier contre docs.qbox.re à l'installation.

local QBX = exports.qbx_core
local playerData = {}
local lastKey = ''

local function refresh()
    local ok, data = pcall(function() return QBX:GetPlayerData() end) -- [API]
    playerData = ok and data or {}
end

local function GetJob()
    local job = playerData.job
    if not job then return nil end
    return {
        name = job.name, label = job.label,
        grade = job.grade and job.grade.level or 0,
        onduty = job.onduty == true,
    }
end

local lastStatus = ''

--- Faim / soif (0-100) et argent. [API] metadata Qbox
local function GetStatus()
    local meta, money = playerData.metadata or {}, playerData.money or {}
    return {
        hunger = math.floor(meta.hunger or 100), thirst = math.floor(meta.thirst or 100),
        cash = money.cash or 0, bank = money.bank or 0,
    }
end

local function pushStatus()
    local s = GetStatus()
    local key = ('%d:%d:%d:%d'):format(s.hunger, s.thirst, s.cash, s.bank)
    if key == lastStatus then return end
    lastStatus = key
    TriggerEvent('gs_bridge:client:statusUpdated', s)
end

-- Ne notifie que si le job, le grade ou le service changent (SetPlayerData arrive très souvent).
local function pushJob()
    local j = GetJob()
    local key = j and ('%s:%s:%s'):format(j.name, j.grade, j.onduty) or ''
    if key == lastKey then return end
    lastKey = key
    TriggerEvent('gs_bridge:client:jobUpdated', j)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() -- [API]
    refresh()
    TriggerEvent('gs_bridge:client:playerLoaded')
    pushJob()
    pushStatus()
end)

-- Nouveau perso : qbx_core (startingApartment = true par défaut) passe la main au choix d'appartement.
-- Sans ressource d'appartements, personne ne répond : écran noir + chargement infini (menus utilisables).
-- On bascule sur l'apparition sans appartement de qbx_core : spawn par défaut, fondu, puis création de l'apparence.
AddEventHandler('apartments:client:setupSpawnUI', function() -- [API] qbx_core client/character.lua
    for _, res in ipairs({ 'qbx_apartments', 'qbx_properties', 'qb-apartments' }) do
        if GetResourceState(res) == 'started' then return end
    end
    TriggerEvent('qbx_core:client:spawnNoApartments')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() -- [API]
    playerData, lastKey, lastStatus = {}, '', ''
    TriggerEvent('gs_bridge:client:playerUnloaded')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) -- [API]
    playerData.job = job
    pushJob()
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty) -- [API]
    if playerData.job then playerData.job.onduty = duty end
    pushJob()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) -- [API]
    playerData = data or {}
    pushJob()
    pushStatus()
end)

CreateThread(function()
    if LocalPlayer.state.isLoggedIn then refresh(); pushJob(); pushStatus() end
end)

local savedAppearance

--- Mémorise l'apparence actuelle (avant un skin boutique / une transformation staff). [API] illenium-appearance
exports('SaveAppearance', function()
    local ok, app = pcall(function() return exports['illenium-appearance']:getPedAppearance(PlayerPedId()) end)
    if ok and app then savedAppearance = app end
    return ok and app ~= nil
end)

--- Remet l'apparence du personnage : celle mémorisée, sinon modèle freemode (selon le genre) + skin enregistré.
--- Asynchrone (thread interne) : un export appelé depuis une autre ressource ne doit pas attendre.
exports('RestoreAppearance', function()
    local app = savedAppearance
    savedAppearance = nil
    CreateThread(function()
        local female = playerData.charinfo and tonumber(playerData.charinfo.gender) == 1
        local hash = GetHashKey(female and 'mp_f_freemode_01' or 'mp_m_freemode_01')
        -- Déjà le bon corps (retour de tenue de service) : on remet seulement vêtements et accessoires, sans changer
        -- de modèle (sinon le perso apparaît chauve et en sous-vêtements une fraction de seconde).
        if app and GetEntityModel(PlayerPedId()) == hash then
            local ok = pcall(function()
                local ped = PlayerPedId()
                exports['illenium-appearance']:setPedComponents(ped, app.components) -- [API]
                exports['illenium-appearance']:setPedProps(ped, app.props) -- [API]
            end)
            if ok then return end
        end
        -- Changement de corps (animal, skin boutique) : écran noir le temps du changement
        DoScreenFadeOut(150)
        Wait(160)
        RequestModel(hash) -- natif : gs_bridge ne charge pas ox_lib (lib = nil ici, c'était le bug du retour humain)
        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
        SetPlayerModel(PlayerId(), hash) -- d'abord un corps humain (depuis un animal, illenium refuse sinon)
        SetPedDefaultComponentVariation(PlayerPedId())
        SetModelAsNoLongerNeeded(hash)
        Wait(250)
        if not (app and pcall(function() exports['illenium-appearance']:setPlayerAppearance(app) end)) then -- [API]
            TriggerEvent('illenium-appearance:client:reloadSkin', true) -- [API] recharge le skin sauvegardé en BDD
            Wait(500)
        end
        DoScreenFadeIn(250)
    end)
end)

exports('GetJob', GetJob)
exports('GetStatus', GetStatus)
exports('IsLoggedIn', function() return playerData.citizenid ~= nil end)
exports('GetItemCount', function(item) return exports.ox_inventory:Search('count', item) or 0 end) -- [API]
exports('OpenStash', function(id) exports.ox_inventory:openInventory('stash', id) end) -- [API]
