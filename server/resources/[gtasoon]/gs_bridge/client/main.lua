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

--- Remet l'apparence sauvegardée du personnage (après un skin boutique). [API] illenium-appearance
exports('RestoreAppearance', function()
    TriggerEvent('illenium-appearance:client:reloadSkin')
end)

exports('GetJob', GetJob)
exports('GetStatus', GetStatus)
exports('IsLoggedIn', function() return playerData.citizenid ~= nil end)
exports('GetItemCount', function(item) return exports.ox_inventory:Search('count', item) or 0 end) -- [API]
exports('OpenStash', function(id) exports.ox_inventory:openInventory('stash', id) end) -- [API]
