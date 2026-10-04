-- gs_business (serveur) · V9 « La doublure » : le patron laisse un PNJ à son apparence tenir son comptoir quand
-- personne n'est en service. Apparence lue dans la base (illenium-appearance) ; la doublure peut être braquée.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Double = { list = {}, robbed = {} } -- list[id] = { cid, name, model, skin, untilAt }

local UNARMED = GetHashKey('WEAPON_UNARMED')
local function now() return os.time() end
local function allowed(id) return Config.Double.businesses[id] == true and Config.Businesses[id] ~= nil end
local function staffed(id) return #JobsApi:GetOnDutyPlayers(id) > 0 end
local function boss(src, id)
    local j = Bridge:GetJob(src)
    return j ~= nil and j.name == id and j.isboss == true
end

local function save(id) SetResourceKvp('double:' .. id, Double.list[id] and json.encode(Double.list[id]) or '') end

--- Doublure visible et au travail (pas d'employé en service, pas expirée)
function Double.active(id)
    local d = Double.list[id]
    if not d then return false end
    if now() > d.untilAt then Double.list[id] = nil save(id) return false end
    return not staffed(id)
end

function Double.publish()
    local out = {}
    for id, d in pairs(Double.list) do
        if Double.active(id) then out[id] = { name = d.name, model = d.model, skin = d.skin } end
    end
    GlobalState.gsDoubles = out
end

--- Apparence actuelle du personnage [API] illenium-appearance : table playerskins (citizenid, model, skin, active)
function Double.appearance(cid)
    local row = MySQL.single.await('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { cid })
    return row and row.model, row and row.skin
end

function Double.set(src, id)
    if not allowed(id) then return false, 'Pas de doublure pour ce commerce.' end
    if not boss(src, id) then return false, 'Réservé au patron.' end
    local b = Config.Businesses[id]
    if not Security:InRange(src, b.register, Config.Range + 2.0) then return false, 'Viens au comptoir.' end
    local cid = Bridge:GetIdentifier(src)
    local model, skin = Double.appearance(cid)
    if not model or not skin then return false, 'Apparence introuvable : passe d\'abord chez le coiffeur ou au magasin de vêtements.' end
    Double.list[id] = { cid = cid, name = Bridge:GetName(src) or '?', model = model, skin = skin, untilAt = now() + Config.Double.hours * 3600 }
    save(id)
    Double.publish()
    return true, ('Ta doublure tient le %s quand personne n\'est en service (%d h, puis repasse la renouveler).'):format(b.label, Config.Double.hours)
end

function Double.clear(src, id)
    if not Double.list[id] then return false, 'Aucune doublure ici.' end
    if not boss(src, id) then return false, 'Réservé au patron.' end
    Double.list[id] = nil
    save(id)
    Double.publish()
    return true, 'Tu reprends ta place : plus de doublure.'
end

--- Braquage de la doublure : arme en main, à portée, une fois toutes les 2 h par commerce ; pris sur la caisse du commerce
function Double.rob(src, id)
    local R = Config.Double.rob
    local b = Config.Businesses[id]
    if not b or not Double.active(id) then return false, 'Il n\'y a personne à braquer.' end
    local ped = GetPlayerPed(src)
    if GetSelectedPedWeapon(ped) == UNARMED then return false, 'Sans arme, elle te rit au nez.' end
    if not Security:InRange(src, b.craft, R.range + 3.0) then return false, 'Approche-toi du comptoir.' end
    if Double.robbed[id] and now() - Double.robbed[id] < R.cooldown then return false, 'La caisse vient d\'être vidée.' end
    if Bridge:GetSourceByIdentifier(Double.list[id].cid) == src then return false, 'Te braquer toi-même ?' end
    Double.robbed[id] = now()
    local cash = JobsApi:GetSocietyMoney(id) or 0
    local take = math.min(R.max, math.max(R.min, math.floor(cash * R.pct)))
    take = math.min(take, cash)
    if take <= 0 then return false, 'La caisse est vide.' end
    if not JobsApi:RemoveSocietyMoney(id, take) then return false, 'La caisse est vide.' end
    if Bridge:ItemExists('black_money') then Bridge:AddItem(src, 'black_money', take) else Bridge:AddMoney(src, 'cash', take, 'braquage') end
    if GetResourceState('gs_wanted') == 'started' then
        pcall(function() exports.gs_wanted:ReportCrime(src, 'store_robbery', vec3(b.register.x, b.register.y, b.register.z)) end)
    end
    local owner = Bridge:GetSourceByIdentifier(Double.list[id].cid)
    if owner then Bridge:Notify(owner, ('Ta doublure du %s s\'est fait braquer (%d $ pris dans la caisse).'):format(b.label, take), 'error') end
    Store.log(id, 'robbery', 'caisse', 1, take, 'Braquage de la doublure')
    return true, ('Elle vide la caisse : %d $.'):format(take)
end

lib.callback.register('gs_business:double', function(src, action, id)
    if not Security:RateLimit(src, 'gs_business:double', 3, 5000) then return false, 'Doucement.' end
    id = tostring(id or '')
    if action == 'set' then return Double.set(src, id) end
    if action == 'clear' then return Double.clear(src, id) end
    if action == 'rob' then return Double.rob(src, id) end
    return false, 'Action inconnue.'
end)

CreateThread(function()
    for id in pairs(Config.Double.businesses) do
        local raw = GetResourceKvpString('double:' .. id)
        if raw and raw ~= '' then
            local ok, d = pcall(json.decode, raw)
            if ok and type(d) == 'table' and d.cid then Double.list[id] = d end
        end
    end
    while true do Double.publish() Wait(30000) end
end)
