-- gs_bridge (serveur) : API stable pour nos ressources gs_*.
-- Règle : aucune autre ressource n'appelle qbx_core / ox_inventory / qbx_vehiclekeys directement.
-- Changer de framework = réécrire ce fichier + client/main.lua, rien d'autre.
-- Ne valide PAS l'intention du joueur (distance, rate-limit) : c'est le rôle de gs_security côté appelant.
-- [API] = appel framework à vérifier contre docs.qbox.re / overextended.dev à l'installation.
-- Les exports ne renvoient que des données simples (jamais l'objet Player : trop lourd à sérialiser).

local QBX = exports.qbx_core
local OX  = exports.ox_inventory

local VALID_ACCOUNTS = { cash = true, bank = true }
local MAX_AMOUNT = 100000000

local function positiveInt(n)
    return type(n) == 'number' and n > 0 and n == math.floor(n) and n <= MAX_AMOUNT
end

-- Joueurs ------------------------------------------------------------------------

local function GetPlayer(src)
    if type(src) ~= 'number' or src <= 0 then return nil end
    return QBX:GetPlayer(src) -- [API]
end

local function IsLoaded(src) return GetPlayer(src) ~= nil end

--- Liste des sources ayant un personnage chargé.
local function GetPlayers()
    local list = {}
    for src in pairs(QBX:GetQBPlayers()) do list[#list + 1] = src end -- [API]
    return list
end

local function GetIdentifier(src)
    local p = GetPlayer(src)
    return p and p.PlayerData.citizenid or nil
end

local function GetSourceByIdentifier(cid)
    if type(cid) ~= 'string' then return nil end
    local p = QBX:GetPlayerByCitizenId(cid) -- [API]
    return p and p.PlayerData.source or nil
end

local function GetName(src)
    local p = GetPlayer(src)
    if not p then return nil end
    local ci = p.PlayerData.charinfo
    return ('%s %s'):format(ci.firstname, ci.lastname)
end

--- 'male' | 'female' (charinfo.gender Qbox : 0 = homme, 1 = femme). [API]
local function GetGender(src)
    local p = GetPlayer(src)
    if not p then return nil end
    return tonumber(p.PlayerData.charinfo.gender) == 1 and 'female' or 'male'
end

--- Identité (contrôle police) : { firstname, lastname, birthdate, nationality, gender } [API] charinfo Qbox
local function GetCharInfo(src)
    local p = GetPlayer(src)
    if not p then return nil end
    local ci = p.PlayerData.charinfo
    return { firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate, nationality = ci.nationality,
             gender = tonumber(ci.gender) == 1 and 'female' or 'male' }
end

--- Permis (metadata.licences Qbox) : { driver = bool, weapon = bool, ... } [API]
local function GetLicences(src)
    local p = GetPlayer(src)
    return p and p.PlayerData.metadata and p.PlayerData.metadata.licences or {}
end

--- Propriétaire d'un véhicule par sa plaque : nom du personnage ou nil (véhicule volé / PNJ / location). [API] player_vehicles
local function GetVehicleOwner(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('^%s+', ''):gsub('%s+$', '')
    local row = MySQL.single.await([[SELECT p.charinfo FROM player_vehicles v JOIN players p ON p.citizenid = v.citizenid
        WHERE TRIM(v.plate) = ? LIMIT 1]], { plate })
    if not row then return nil end
    local ok, ci = pcall(json.decode, row.charinfo)
    return ok and ci and ('%s %s'):format(ci.firstname, ci.lastname) or '?'
end

-- Jobs ---------------------------------------------------------------------------

---@return { name: string, label: string, grade: number, onduty: boolean }|nil
local function GetJob(src)
    local p = GetPlayer(src)
    if not p then return nil end
    local job = p.PlayerData.job
    return { name = job.name, label = job.label, grade = job.grade.level, onduty = job.onduty == true }
end

local function IsOnDuty(src)
    local j = GetJob(src)
    return j ~= nil and j.onduty
end

--- Change le job ACTIF (la liste des contrats est gérée par gs_jobs).
local function SetJob(src, name, grade)
    local p = GetPlayer(src)
    if not p then return false end
    local ok, res = pcall(p.Functions.SetJob, name, grade) -- [API]
    if not ok then print(('[gs_bridge] SetJob %s/%s a échoué : %s'):format(name, grade, res)) end
    return ok and res ~= false
end

--- Déclare des gangs au framework (grades génériques). [API] qbx_core CreateGangs
local function RegisterGangs(gangs)
    local list = {}
    for name, label in pairs(gangs) do
        list[name] = { label = label, grades = { [0] = { name = 'Recrue' }, [1] = { name = 'Membre' },
            [2] = { name = 'Bras droit' }, [3] = { name = 'Chef', isboss = true } } }
    end
    local ok, err = pcall(function() return QBX:CreateGangs(list) end) -- [API]
    if not ok then print(('[gs_bridge] CreateGangs a échoué : %s'):format(err)) end
    return ok
end

--- Gang côté framework (pour que les coffres ox_inventory reconnaissent le gang). gs_gangs fait foi.
local function SetGang(src, name, grade)
    local p = GetPlayer(src)
    if not p then return false end
    local ok, res = pcall(p.Functions.SetGang, name, grade) -- [API]
    return ok and res ~= false
end

local function SetDuty(src, onDuty)
    local p = GetPlayer(src)
    if not p then return false end
    return (pcall(p.Functions.SetJobDuty, onDuty == true)) -- [API]
end

--- Retire le job de la liste multi-job native de Qbox (gs_jobs reste la source de vérité).
local function ForgetJob(cid, name)
    return (pcall(function() QBX:RemovePlayerFromJob(cid, name) end)) -- [API]
end

--- Déclare nos jobs au framework. Salaire à 0 : la paie est gérée par gs_jobs (pas de double paie).
local function RegisterJobs(jobs)
    local list = {}
    for name, def in pairs(jobs) do
        local grades = {}
        for level, g in pairs(def.grades) do
            grades[level] = { name = g.label, payment = 0, isboss = g.boss or nil, bankAuth = g.boss or nil }
        end
        list[name] = { label = def.label, type = def.type, defaultDuty = false, offDutyPay = false, grades = grades }
    end
    local ok, err = pcall(function() return QBX:CreateJobs(list) end) -- [API]
    if not ok then
        print(('[gs_bridge] CreateJobs a échoué (%s) : déclare les jobs dans qbx_core/shared/jobs.lua'):format(err))
    end
    return ok
end

-- Argent -------------------------------------------------------------------------

local function GetMoney(src, account)
    local p = GetPlayer(src)
    if not p or not VALID_ACCOUNTS[account] then return 0 end
    return p.PlayerData.money[account] or 0
end

local function AddMoney(src, account, amount, reason)
    local p = GetPlayer(src)
    if not p or not VALID_ACCOUNTS[account] or not positiveInt(amount) then return false end
    return p.Functions.AddMoney(account, amount, reason or 'gs_bridge') == true -- [API]
end

--- Retire seulement si le solde est suffisant (jamais de solde négatif).
local function RemoveMoney(src, account, amount, reason)
    local p = GetPlayer(src)
    if not p or not VALID_ACCOUNTS[account] or not positiveInt(amount) then return false end
    if GetMoney(src, account) < amount then return false end
    return p.Functions.RemoveMoney(account, amount, reason or 'gs_bridge') == true -- [API]
end

-- Inventaire ---------------------------------------------------------------------

local function CanCarry(src, item, count)
    if not IsLoaded(src) or type(item) ~= 'string' or not positiveInt(count) then return false end
    return OX:CanCarryItem(src, item, count) == true
end

local function GetItemCount(src, item)
    if not IsLoaded(src) or type(item) ~= 'string' then return 0 end
    return OX:GetItemCount(src, item) or 0
end

--- L'item est-il déclaré dans ox_inventory ?
local function ItemExists(item)
    if type(item) ~= 'string' then return false end
    local ok, data = pcall(function() return OX:Items(item) end) -- [API]
    return ok and data ~= nil
end

local function AddItem(src, item, count, metadata)
    if not CanCarry(src, item, count) then return false end
    return OX:AddItem(src, item, count, metadata) and true or false
end

local function RemoveItem(src, item, count, metadata)
    if not positiveInt(count) or GetItemCount(src, item) < count then return false end
    return OX:RemoveItem(src, item, count, metadata) and true or false
end

--- Coffre ox_inventory. `groups` = { job = gradeMin } ; ox_inventory vérifie job + distance à l'ouverture.
local function RegisterStash(id, label, slots, weight, groups, coords)
    local ok, err = pcall(function() OX:RegisterStash(id, label, slots, weight, false, groups, coords) end) -- [API]
    if not ok then print(('[gs_bridge] RegisterStash %s a échoué : %s'):format(id, err)) end
    return ok
end

--- Liste triée { name, label } de tous les items ox_inventory (menus staff). [API]
local function ListItems()
    local list = {}
    local ok, items = pcall(function() return OX:Items() end)
    if not ok or type(items) ~= 'table' then return list end
    for name, it in pairs(items) do list[#list + 1] = { name = name, label = it.label or name } end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

--- Dépôt au sol ramassable par tous. items = { { name, count }, ... }. [API] ox_inventory CustomDrop
local function CreateDrop(items, coords)
    local ok, err = pcall(function() OX:CustomDrop('Dépôt', items, coords) end)
    if not ok then print(('[gs_bridge] CreateDrop a échoué : %s'):format(err)) end
    return ok
end

-- Véhicules ----------------------------------------------------------------------

local function GiveVehicleKeys(src, vehicle)
    if GetResourceState('qbx_vehiclekeys') ~= 'started' then return false end
    return (pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, vehicle) end)) -- [API]
end

local VEHICLE_TYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true, submarine = true, trailer = true, train = true }

--- Véhicule temporaire (location, quête, staff) créé côté serveur, clés données, joueur placé dedans si warp.
--- Retourne l'entité (0 si échec). La plaque est `plate` (8 caractères max).
local function SpawnVehicle(src, model, vtype, coords, heading, plate, warp)
    if type(model) ~= 'string' or not VEHICLE_TYPES[vtype or 'automobile'] then return 0 end
    local veh = CreateVehicleServerSetter(GetHashKey(model), vtype or 'automobile', coords.x, coords.y, coords.z, heading or 0.0)
    if not veh or veh == 0 then return 0 end
    if plate then SetVehicleNumberPlateText(veh, plate:sub(1, 8)) end
    if warp then TaskWarpPedIntoVehicle(GetPlayerPed(src), veh, -1) end
    GiveVehicleKeys(src, veh)
    return veh
end

--- Véhicule possédé ajouté au garage du personnage (boutique, récompenses). Retourne true si créé.
local function GiveVehicle(src, model)
    local cid = GetIdentifier(src)
    if not cid or type(model) ~= 'string' then return false end
    local ok, id = pcall(function()
        return exports.qbx_vehicles:CreatePlayerVehicle({ model = model, citizenid = cid }) -- [API]
    end)
    if not ok then print(('[gs_bridge] GiveVehicle %s a échoué : %s'):format(model, id)) end
    return ok and id ~= nil
end

--- Réanimation / soin complet via le système médical du framework. [API] qbx_medical
local function Revive(src)
    if not IsLoaded(src) then return false end
    local ok = pcall(function() exports.qbx_medical:Revive(src) end) -- [API]
    if not ok then TriggerClientEvent('qbx_medical:client:playerRevived', src) end -- [API] repli
    return true
end

--- Joueur à terre ou mort (qbx_medical : 1 vivant, 2 à terre, 3 mort). [API] state bag qbx_medical
local function IsDowned(src)
    if not IsLoaded(src) then return false end
    local state = Player(src).state['qbx_medical:deathState']
    return state ~= nil and state >= 2
end

-- UI -----------------------------------------------------------------------------

--- type: 'inform' | 'success' | 'error' | 'warning'
local function Notify(src, description, ntype)
    TriggerClientEvent('ox_lib:notify', src, { description = tostring(description):sub(1, 200), type = ntype or 'inform' })
end

-- Cycle de vie : événements neutres pour nos ressources (AddEventHandler = non déclenchables par un client)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player) -- [API]
    TriggerEvent('gs_bridge:server:playerLoaded', player.PlayerData.source)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) -- [API]
    TriggerEvent('gs_bridge:server:playerUnloaded', src)
end)

AddEventHandler('playerDropped', function()
    TriggerEvent('gs_bridge:server:playerUnloaded', source)
end)

exports('IsLoaded', IsLoaded)
exports('GetPlayers', GetPlayers)
exports('GetIdentifier', GetIdentifier)
exports('GetSourceByIdentifier', GetSourceByIdentifier)
exports('GetName', GetName)
exports('GetGender', GetGender)
exports('GetCharInfo', GetCharInfo)
exports('GetLicences', GetLicences)
exports('GetVehicleOwner', GetVehicleOwner)
exports('ListItems', ListItems)
exports('CreateDrop', CreateDrop)
exports('SpawnVehicle', SpawnVehicle)
exports('GetJob', GetJob)
exports('IsOnDuty', IsOnDuty)
exports('SetJob', SetJob)
exports('SetDuty', SetDuty)
exports('SetGang', SetGang)
exports('RegisterGangs', RegisterGangs)
exports('ForgetJob', ForgetJob)
exports('RegisterJobs', RegisterJobs)
exports('GetMoney', GetMoney)
exports('AddMoney', AddMoney)
exports('RemoveMoney', RemoveMoney)
exports('CanCarry', CanCarry)
exports('GetItemCount', GetItemCount)
exports('ItemExists', ItemExists)
exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('RegisterStash', RegisterStash)
exports('GiveVehicleKeys', GiveVehicleKeys)
exports('GiveVehicle', GiveVehicle)
exports('Revive', Revive)
exports('IsDowned', IsDowned)
exports('Notify', Notify)
