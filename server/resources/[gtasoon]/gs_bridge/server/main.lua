-- gs_bridge : API stable pour nos ressources gs_*. Aucune autre ressource ne doit appeler
-- qbx_core / ox_inventory directement. Si on change de framework, on ne réécrit que ce fichier.
-- Toutes les fonctions sont SERVEUR uniquement. Elles ne valident PAS l'intention du joueur
-- (distance, rate-limit) : c'est le rôle de gs_security côté appelant.
-- À vérifier contre docs.qbox.re / overextended.dev à l'installation (les API bougent selon les versions).

local QBX = exports.qbx_core
local OX  = exports.ox_inventory

local VALID_ACCOUNTS = { cash = true, bank = true }

local function positiveInt(n)
    return type(n) == 'number' and n > 0 and n == math.floor(n) and n < 2 ^ 31
end

---@return table|nil player objet Qbox ou nil si hors ligne / source invalide
local function GetPlayer(src)
    if type(src) ~= 'number' or src <= 0 then return nil end
    return QBX:GetPlayer(src)
end

---@return string|nil citizenid
local function GetIdentifier(src)
    local p = GetPlayer(src)
    return p and p.PlayerData.citizenid or nil
end

---@return { name: string, grade: number, label: string }|nil
local function GetJob(src)
    local p = GetPlayer(src)
    if not p then return nil end
    local job = p.PlayerData.job
    return { name = job.name, grade = job.grade.level, label = job.label }
end

local function IsOnDuty(src)
    local p = GetPlayer(src)
    return p ~= nil and p.PlayerData.job.onduty == true
end

--- Permission ACE (ex: 'command', 'group.admin'). Jamais de liste d'admins en dur.
local function HasPermission(src, ace)
    return type(ace) == 'string' and IsPlayerAceAllowed(src, ace)
end

local function GetMoney(src, account)
    local p = GetPlayer(src)
    if not p or not VALID_ACCOUNTS[account] then return 0 end
    return p.PlayerData.money[account] or 0
end

local function AddMoney(src, account, amount, reason)
    local p = GetPlayer(src)
    if not p or not VALID_ACCOUNTS[account] or not positiveInt(amount) then return false end
    return p.Functions.AddMoney(account, amount, reason or 'gs_bridge') == true
end

--- Retire seulement si le solde est suffisant (jamais de solde négatif).
local function RemoveMoney(src, account, amount, reason)
    local p = GetPlayer(src)
    if not p or not VALID_ACCOUNTS[account] or not positiveInt(amount) then return false end
    if GetMoney(src, account) < amount then return false end
    return p.Functions.RemoveMoney(account, amount, reason or 'gs_bridge') == true
end

local function CanCarry(src, item, count)
    if not GetPlayer(src) or type(item) ~= 'string' or not positiveInt(count) then return false end
    return OX:CanCarryItem(src, item, count) == true
end

local function GetItemCount(src, item)
    if not GetPlayer(src) or type(item) ~= 'string' then return 0 end
    return OX:GetItemCount(src, item) or 0
end

local function AddItem(src, item, count, metadata)
    if not CanCarry(src, item, count) then return false end
    return OX:AddItem(src, item, count, metadata) and true or false
end

local function RemoveItem(src, item, count, metadata)
    if not positiveInt(count) or GetItemCount(src, item) < count then return false end
    return OX:RemoveItem(src, item, count, metadata) and true or false
end

--- Notification via ox_lib. type: 'inform' | 'success' | 'error' | 'warning'
local function Notify(src, description, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        description = tostring(description):sub(1, 200),
        type = ntype or 'inform',
    })
end

exports('GetPlayer', GetPlayer)
exports('GetIdentifier', GetIdentifier)
exports('GetJob', GetJob)
exports('IsOnDuty', IsOnDuty)
exports('HasPermission', HasPermission)
exports('GetMoney', GetMoney)
exports('AddMoney', AddMoney)
exports('RemoveMoney', RemoveMoney)
exports('CanCarry', CanCarry)
exports('GetItemCount', GetItemCount)
exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('Notify', Notify)
