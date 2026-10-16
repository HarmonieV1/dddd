-- gs_animalerie (serveur) · V12.63. Tout se décide ici : service (gs_jobs), distance au poste, attente entre deux tâches,
-- carton porté pour les gamelles, client présent au comptoir, paie (ville → banque). Position de la map lue chez gs_admin.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Petshop = { cooldown = {}, carrying = {}, nextCustomer = {}, tracked = {} }

local function onDuty(src)
    if GetResourceState('gs_jobs') ~= 'started' then return false end
    local ok, v = pcall(function() return exports.gs_jobs:IsOnDutyAs(src, Config.Job) end)
    return ok and v == true
end

--- Position de la map de l'animalerie (gs_admin, analyse des maps installées : centre des objets du bâtiment), ou nil
function Petshop.findAnchor()
    if GetResourceState('gs_admin') ~= 'started' then return nil end
    local ok, scan = pcall(function() return exports.gs_admin:MapScan() end)
    if not ok or type(scan) ~= 'table' or type(scan.maps) ~= 'table' then return nil end
    for _, m in ipairs(scan.maps) do
        local p = type(m) == 'table' and type(m.name) == 'string' and m.name:lower():find(Config.Map, 1, true) and type(m.places) == 'table' and m.places[1]
        if p and tonumber(p.x) then return { x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0 } end
    end
    return nil
end

local C = Config.Customers

--- Client du comptoir (par employé) : prochain passage, et client parti s'il a trop attendu
local function customerState(src, now)
    local at = Petshop.nextCustomer[src]
    if not at or now > at + C.wait then
        Petshop.nextCustomer[src] = now + math.random(C.every[1], C.every[2])
    end
    return Petshop.nextCustomer[src]
end

function Petshop.task(src, name)
    local t = Config.Tasks[name]
    if not t then return false, 'Tâche inconnue.' end
    if not onDuty(src) then return false, 'Prends ton service d\'animalerie d\'abord (menu des métiers).' end
    local at = Config.PostAt(t.post, GlobalState.gsPetshopAnchor)
    if not at then return false, 'Les postes de l\'animalerie ne sont pas encore placés (staff : F11 → Déplacer un point).' end
    if not Security:InRange(src, vec3(at.x, at.y, at.z), Config.Range + 1.5) then return false, 'Approche-toi du poste.' end
    local now = os.time()
    Petshop.cooldown[src] = Petshop.cooldown[src] or {}
    local cd = Petshop.cooldown[src][name]
    if cd and now < cd then return false, ('Déjà fait : reviens dans %d s.'):format(cd - now) end
    if t.needs and not (Petshop.carrying[src] and now - Petshop.carrying[src] <= Config.Carry.seconds) then
        return false, 'Il te faut d\'abord un carton de croquettes (réserve).'
    end
    if name == 'serve' then
        local due = customerState(src, now)
        if now < due then return false, 'Pas de client pour l\'instant.' end
        Petshop.nextCustomer[src] = now + math.random(C.every[1], C.every[2])
    end
    if t.cooldown then Petshop.cooldown[src][name] = now + t.cooldown end
    if name == 'stock' then Petshop.carrying[src] = now return true, 'Carton de croquettes en main : direction les gamelles.' end
    if t.needs then Petshop.carrying[src] = nil end
    local pay = math.random(t.pay[1], t.pay[2])
    local tip = t.tip and math.random(t.tip[1], t.tip[2]) or 0
    Bridge:AddMoney(src, 'bank', pay + tip, 'animalerie')
    if (not Petshop.tracked[src] or now - Petshop.tracked[src] >= 600) and GetResourceState('gs_quests') == 'started' then -- XP de métier : au plus toutes les 10 min
        Petshop.tracked[src] = now
        pcall(function() exports.gs_quests:Track(src, 'job_mission') end)
    end
    return true, tip > 0 and ('%s : +%d $ (+%d $ de pourboire).'):format(t.label, pay, tip) or ('%s : +%d $.'):format(t.label, pay)
end

lib.callback.register('gs_animalerie:task', function(src, name)
    if not Security:RateLimit(src, 'gs_animalerie:task', 4, 10000) then return false, 'Doucement.' end
    return Petshop.task(src, name)
end)

--- État pour le client : service, client attendu dans X s (ou présent : 0), carton en main
lib.callback.register('gs_animalerie:state', function(src)
    if not Security:RateLimit(src, 'gs_animalerie:state', 6, 10000) then return nil end
    local duty = onDuty(src)
    local now = os.time()
    local carry = Petshop.carrying[src]
    return { duty = duty, customerIn = duty and math.max(0, customerState(src, now) - now) or nil,
        carrying = carry ~= nil and now - carry <= Config.Carry.seconds }
end)

AddEventHandler('playerDropped', function()
    local src = source
    Petshop.cooldown[src], Petshop.carrying[src], Petshop.nextCustomer[src], Petshop.tracked[src] = nil, nil, nil, nil
end)

-- Position de la map : cherchée au démarrage (après l'analyse des maps de gs_admin), puis toutes les 5 min
CreateThread(function()
    Wait(20000)
    while true do
        local a = Petshop.findAnchor()
        if a then GlobalState.gsPetshopAnchor = a end
        Wait(300000)
    end
end)
