-- gs_security · V12.4 « Pots de miel ». Des events et des callbacks qu'AUCUN script RoadLine ne déclenche jamais :
--  1. des noms de frameworks qu'on n'utilise pas (ESX, vieux scripts fuités) que les menus de triche essaient en aveugle ;
--  2. des noms qui ressemblent à une faille (« donne-moi de l'argent », « passe-moi admin »), appâts pour qui fouille.
-- Un client qui en déclenche un ne peut pas l'avoir fait en jouant : c'est un menu de triche. Zéro faux positif.
-- Réglage : convar `gs_honeypot` = "ban" (défaut), "kick" ou "log". Le staff n'est jamais banni, seulement signalé.
-- Attention en ajoutant un nom : il ne doit exister NULLE PART ailleurs dans le dépôt (tests/check_honeypot.py le vérifie).

local DAYS = 0 -- bannissement définitif (triche confirmée)

--- Noms d'events « appât ». Chacun est enregistré comme event réseau : le déclencher est la preuve.
local EVENTS = {
    -- Frameworks et scripts qu'on n'utilise pas : les menus de triche les tentent systématiquement
    'esx:getSharedObject', 'esx_society:putVehicleInGarage', 'esx_ambulancejob:revive',
    'esx_policejob:handcuff', 'esx_skin:responseSaveSkin', 'esx_vehicleshop:setVehicleOwned',
    'bank:server:deposit', 'bank:server:withdraw', 'InteractSound_SV:PlayWithinDistance',
    'mellotrainer:adminTempBan', 'wk:spawnVehicle', 'AdminMenu:giveItem',
    -- Appâts « faille » : ce qu'un tricheur espère trouver chez nous (aucun de ces noms n'existe côté client)
    'gs_bank:server:addMoney', 'gs_bank:server:setBalance', 'gs_admin:server:giveMoney',
    'gs_admin:server:setRank', 'gs_admin:server:grantAdmin', 'gs_jobs:server:setGrade',
    'gs_quests:server:grantLevel', 'gs_store:server:claimAll', 'gs_gangs:server:setMoney',
    'gs_economy:server:freeItem', 'gs_police:server:clearRecord',
}

--- Noms de callbacks « appât » (lib.callback) : même logique.
local CALLBACKS = {
    'gs_bank:giveMoney', 'gs_admin:grantAdmin', 'gs_store:claimAll', 'gs_quests:setLevel',
}

local function name(src) return ('%s [%s]'):format(GetPlayerName(src) or '?', src) end

--- Réaction au déclenchement d'un piège : journal staff, alerte, puis sanction selon la convar.
local function trap(src, what)
    src = tonumber(src)
    if not src or src <= 0 then return end -- déclenché côté serveur (jamais le cas, mais on ne sanctionne pas à l'aveugle)
    local mode = GetConvar('gs_honeypot', 'ban')
    local reason = ('Pot de miel déclenché : %s'):format(what)
    GSSec.LogStaff(('[Anti-triche] PIÈGE · %s : %s (mode %s)'):format(name(src), what, mode), 'anticheat')
    if GetResourceState('gs_admin') == 'started' then
        pcall(function() exports.gs_admin:NotifyStaff(('Anti-triche · PIÈGE : %s a déclenché %s'):format(name(src), what)) end)
    end
    if mode == 'log' then return end
    if mode == 'ban' and GetResourceState('gs_admin') == 'started' then
        local ok = pcall(function() return exports.gs_admin:AutoBan(src, reason, DAYS) end)
        if ok then return end
    end
    DropPlayer(src, 'Triche détectée (menu de triche).\n\nContestation : notre Discord.')
end

for _, ev in ipairs(EVENTS) do
    RegisterNetEvent(ev, function() trap(source, 'event ' .. ev) end)
end

if lib and lib.callback and lib.callback.register then
    for _, cb in ipairs(CALLBACKS) do
        lib.callback.register(cb, function(src) trap(src, 'callback ' .. cb) return false end)
    end
end

--- [API] pour les tests et un éventuel piège posé ailleurs.
GSSec.Honeypot = { events = EVENTS, callbacks = CALLBACKS, trap = trap }
