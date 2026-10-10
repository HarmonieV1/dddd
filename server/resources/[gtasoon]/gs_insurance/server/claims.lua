-- gs_insurance (serveur) · V9 « Fraude à l'assurance » : déclarer sa voiture volée, toucher l'indemnité… et espérer que
-- l'expert ne recoupe pas avec le carnet du véhicule (gs_carnet). Propriétaire revu au volant ou voiture revendue = fraude.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Claims = { list = {}, seen = {} } -- list[vehicleId] = { id, plate, cid, amount, status, at } ; seen[plate] = { cid, at }

local function now() return os.time() end
local function trim(p) return (tostring(p or '')):gsub('^%s+', ''):gsub('%s+$', '') end

local function byPlate(plate)
    for _, c in pairs(Claims.list) do if c.plate == plate and (c.status == 'pending' or c.status == 'paid') then return c end end
end

local function notifyCid(cid, msg, t)
    local src = Bridge:GetSourceByIdentifier(cid)
    if src then Bridge:Notify(src, msg, t or 'inform') end
    return src
end

local function save(c) Store.saveClaim(c) end

--- Déclaration au guichet : contrôles de l'expert avant d'ouvrir le dossier
function Claims.declare(src, id)
    local C = Config.Claim
    id = math.floor(tonumber(id) or 0)
    local cid = Bridge:GetIdentifier(src)
    if not cid or id <= 0 or not Store.owns(cid, id) then return false, 'Ce véhicule n\'est pas à toi.' end
    if not Insurance.isInsured(id) then return false, 'Ce véhicule n\'est pas assuré : rien à indemniser.' end
    if Claims.list[id] and Claims.list[id].status ~= 'closed' then return false, 'Un dossier est déjà ouvert pour ce véhicule.' end
    local since = GetResourceKvpInt('since:' .. id)
    if since > 0 and now() - since < C.minInsuredHours * 3600 then
        return false, ('« Assuré depuis moins de %d h et déjà volé ? » L\'expert refuse le dossier.'):format(C.minInsuredHours)
    end
    local last = GetResourceKvpInt('claimcd:' .. cid)
    if last > 0 and now() - last < C.cooldownDays * 86400 then return false, 'Encore toi ? L\'assurance n\'ouvre plus de dossier à ton nom pour le moment.' end
    local model, plate
    for _, v in ipairs(Store.vehicles(cid)) do if v.id == id then model, plate = v.model, trim(v.plate) end end
    local seen = Claims.seen[plate]
    if seen and seen.cid == cid and now() - seen.at < C.recent * 60 then
        return false, '« Votre voiture a été vue avec vous au volant il y a quelques minutes. » Dossier refusé.'
    end
    local price = Bridge:GetVehiclePrice(model) or Config.DefaultPrice
    local c = { id = id, plate = plate, cid = cid, amount = math.min(C.max, math.floor(price * C.rate)), status = 'pending', at = now() }
    Claims.list[id] = c
    save(c)
    SetResourceKvpInt('claimcd:' .. cid, now())
    return true, ('Dossier ouvert : %d $ après %d min d\'enquête de l\'expert. Le véhicule devient la propriété de l\'assurance : s\'il refait surface, ne le conduis pas.'):format(c.amount, C.review)
end

local function alertPolice(c, why)
    if GetResourceState('gs_jobs') ~= 'started' then return end
    local ok, cops = pcall(function() return exports.gs_jobs:GetOnDutyPlayers('police') end)
    for _, s in ipairs(ok and cops or {}) do
        Bridge:Notify(s, ('Mors Mutual signale une fraude : véhicule %s (%s).'):format(c.plate, why), 'warning')
    end
end

--- L'arnaque est découverte
function Claims.fraud(c, why)
    local C = Config.Claim
    local wasPaid = c.status == 'paid'
    c.status = 'fraud'
    save(c)
    local fine = wasPaid and math.floor(c.amount * (1 + C.penalty)) or 0
    local src = Bridge:GetSourceByIdentifier(c.cid)
    local taken = 0
    if src and fine > 0 then
        if Bridge:RemoveMoney(src, 'bank', fine, 'remboursement assurance') then taken = fine
        elseif Bridge:RemoveMoney(src, 'cash', fine, 'remboursement assurance') then taken = fine end
    end
    if GetResourceState('gs_police') == 'started' then
        pcall(function() exports.gs_police:AddRecord(c.cid, ('%s (%s, %s)'):format(C.charge, c.plate, why), fine - taken, 0, 'Mors Mutual') end)
    end
    if src then Bridge:Notify(src, ('L\'expert a découvert l\'arnaque (%s). %s'):format(why,
        fine > 0 and (taken > 0 and ('%d $ repris.'):format(taken) or 'Dette inscrite à ton casier.') or 'Dossier transmis à la police.'), 'error') end
    alertPolice(c, why)
    if GetResourceState('gs_rumors') == 'started' then
        pcall(function() exports.gs_rumors:Add('l\'assurance a coincé un petit malin', ('Une fausse déclaration de vol (%s), l\'expert a tout recoupé.'):format(c.plate)) end)
    end
end

--- Le carnet signale un conducteur : propriétaire revu au volant après sa déclaration ?
function Claims.driven(plate, src)
    plate = trim(plate)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    Claims.seen[plate] = { cid = cid, at = now() }
    local c = byPlate(plate)
    if not c or c.cid ~= cid then return end
    -- V12 : voiture qui avait refait surface (registre des disparus) et que le propriétaire reprend : pas une fraude
    if Lost and Lost.list[c.id] then return Lost.recovered(c, src) end
    if c.status == 'pending' then
        c.status = 'closed'
        save(c)
        Bridge:Notify(src, 'Mors Mutual : véhicule retrouvé, dossier de vol classé sans indemnité.', 'warning')
    else
        Claims.fraud(c, 'propriétaire revu au volant')
    end
end

--- Le carnet signale un changement de propriétaire : voiture « volée » revendue
function Claims.ownerChanged(plate)
    local c = byPlate(trim(plate))
    if not c then return end
    local owner = Store.ownerOf(c.plate)
    if owner and owner ~= c.cid then Claims.fraud(c, 'véhicule revendu') end
end

--- Versements après l'enquête (propriétaire connecté)
function Claims.tick()
    for _, c in pairs(Claims.list) do
        if c.status == 'pending' and now() - c.at >= Config.Claim.review * 60 then
            local src = Bridge:GetSourceByIdentifier(c.cid)
            if src and Bridge:AddMoney(src, 'bank', c.amount, 'indemnité assurance') then
                c.status = 'paid'
                save(c)
                Insurance.expires[c.id] = nil
                Store.set(c.id, 0)
                Bridge:Notify(src, ('Mors Mutual : indemnité de vol versée (%d $).'):format(c.amount), 'success')
            end
        end
    end
end

function Claims.isStolen(plate) return byPlate(trim(plate)) ~= nil end

AddEventHandler('gs_carnet:server:driven', function(plate, src) Claims.driven(plate, src) end)
AddEventHandler('gs_carnet:server:ownerChanged', function(plate) Claims.ownerChanged(plate) end)

lib.callback.register('gs_insurance:claim', function(src, id)
    if not Security:RateLimit(src, 'gs_insurance:claim', 2, 10000) then return false, 'Doucement.' end
    if not Security:InRange(src, Config.Counter.coords, Config.Range + 1.5) then return false, 'Présente-toi au guichet.' end
    return Claims.declare(src, id)
end)

exports('IsDeclaredStolen', Claims.isStolen)

CreateThread(function()
    Wait(2000)
    Store.initLost()
    for _, c in ipairs(Store.claims()) do Claims.list[c.id] = c end
    while true do Wait(60000) Claims.tick() end
end)
