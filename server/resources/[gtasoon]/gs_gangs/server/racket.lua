-- gs_gangs (serveur) · V9 « Racket des commerces » : un membre du gang réclame une protection hebdomadaire au patron
-- d'un commerce de joueur. Accepté : prélèvement automatique de la caisse du commerce vers la caisse du gang.
-- Refusé ou impayé : le gang a 30 min pour « faire passer le message » (vitrine cassée, dégâts, police alertée).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Racket = { deals = {}, pending = {}, grudge = {}, last = {} }
-- deals[biz] = { gang, amount, next } ; pending[biz] = { gang, amount, by, at } ; grudge[biz] = { gang, untilAt }

local function now() return os.time() end
local function R() return Config.Racket end
local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end
local function notifyGang(gang, msg, t) for s, m in pairs(Gangs.online) do if m.gang == gang then notify(s, msg, t) end end end
local function gangLabel(g) return Gangs.list[g] and Gangs.list[g].label or g end

local function save()
    SetResourceKvp('racket', json.encode({ deals = Racket.deals, grudge = Racket.grudge }))
end

local function businesses()
    if GetResourceState('gs_business') ~= 'started' then return {} end
    local ok, list = pcall(function() return exports.gs_business:GetBusinesses() end)
    return ok and list or {}
end

local function isOwner(src, biz)
    local ok, yes = pcall(function() return exports.gs_business:IsOwner(src, biz) end)
    return ok and yes == true
end

local function owners(biz)
    local out = {}
    for _, s in ipairs(Bridge:GetPlayers() or {}) do if isOwner(s, biz) then out[#out + 1] = s end end
    return out
end

--- Commerce dont la caisse est à portée
function Racket.businessAt(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    for id, b in pairs(businesses()) do
        if #(pos - vec3(b.register.x, b.register.y, b.register.z)) <= R().range then return id, b end
    end
end

local function society(fn, biz, amount)
    if GetResourceState('gs_jobs') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.gs_jobs[fn](exports.gs_jobs, biz, amount) end)
    return ok and res == true
end

local function alertPolice(msg)
    if GetResourceState('gs_jobs') ~= 'started' then return end
    local ok, cops = pcall(function() return exports.gs_jobs:GetOnDutyPlayers(Config.PoliceJob) end)
    for _, s in ipairs(ok and cops or {}) do notify(s, msg, 'warning') end
end

--- Un membre du gang réclame la protection
function Racket.demand(src, amount)
    local m = Gangs.online[src]
    if not m or not m.gang then return false, 'Tu n\'es dans aucun gang.' end
    if (m.grade or 0) < R().minGrade then return false, 'Les recrues ne négocient pas.' end
    local biz, b = Racket.businessAt(src)
    if not biz then return false, 'Va voir le commerce, à la caisse.' end
    amount = math.floor(tonumber(amount) or 0)
    if amount < R().min or amount > R().max then return false, ('Entre %d et %d $ par semaine.'):format(R().min, R().max) end
    local d = Racket.deals[biz]
    if d then return false, d.gang == m.gang and 'Ce commerce paie déjà votre protection.' or ('Le %s est déjà « protégé » par les %s.'):format(b.label, gangLabel(d.gang)) end
    if Racket.pending[biz] and now() - Racket.pending[biz].at < R().answer then return false, 'Le patron réfléchit déjà à une offre.' end
    if Racket.last[biz] and now() - Racket.last[biz] < R().cooldown then return false, 'Trop tôt : laisse-le transpirer un peu.' end
    local bosses = owners(biz)
    if #bosses == 0 then return false, 'Le patron n\'est pas là. Reviens quand il y sera.' end
    Racket.last[biz] = now()
    Racket.pending[biz] = { gang = m.gang, amount = amount, by = src, at = now() }
    for _, s in ipairs(bosses) do
        TriggerClientEvent('gs_gangs:client:racketOffer', s, { biz = biz, label = b.label, gang = gangLabel(m.gang), amount = amount, every = R().every })
    end
    return true, ('Offre faite au patron du %s : %d $ par semaine. Il a %d s pour répondre.'):format(b.label, amount, R().answer)
end

--- Réponse du patron : 'accept' | 'refuse' | 'police'
function Racket.answer(src, biz, choice)
    local p = Racket.pending[biz]
    if not p or now() - p.at > R().answer then Racket.pending[biz] = nil return false, 'L\'offre n\'est plus valable.' end
    if not isOwner(src, biz) then return false, 'Ce n\'est pas ton commerce.' end
    local label = (businesses()[biz] or {}).label or biz
    Racket.pending[biz] = nil
    if choice == 'accept' then
        if not society('RemoveSocietyMoney', biz, p.amount) then
            Racket.grudge[biz] = { gang = p.gang, untilAt = now() + R().grudge }
            save()
            notifyGang(p.gang, ('Le %s n\'a pas de quoi payer. À vous de voir.'):format(label), 'warning')
            return false, 'La caisse est vide : ils ne vont pas aimer.'
        end
        Store.addMoney(p.gang, p.amount)
        Racket.deals[biz] = { gang = p.gang, amount = p.amount, next = now() + R().every * 86400 }
        save()
        notifyGang(p.gang, ('Le %s paie : +%d $ dans la caisse du gang, chaque semaine.'):format(label, p.amount), 'success')
        return true, ('Protection payée : %d $ prélevés sur la caisse, chaque semaine.'):format(p.amount)
    end
    Racket.grudge[biz] = { gang = p.gang, untilAt = now() + R().grudge }
    save()
    notifyGang(p.gang, ('Le patron du %s refuse. Vous avez %d min pour faire passer le message.'):format(label, math.floor(R().grudge / 60)), 'warning')
    if choice == 'police' then
        alertPolice(('Le patron du %s signale un racket des %s.'):format(label, gangLabel(p.gang)))
        return true, 'Refusé, et la police est prévenue.'
    end
    return true, 'Refusé. Fais attention à ta vitrine.'
end

--- Le patron arrête de payer
function Racket.stop(src, biz)
    local d = Racket.deals[biz]
    if not d or not isOwner(src, biz) then return false, 'Aucune protection à arrêter.' end
    Racket.deals[biz] = nil
    Racket.grudge[biz] = { gang = d.gang, untilAt = now() + R().grudge }
    save()
    notifyGang(d.gang, ('Le %s ne veut plus payer.'):format((businesses()[biz] or {}).label or biz), 'warning')
    return true, 'Tu ne paies plus. Ils vont venir.'
end

--- « Faire passer le message » : vitrine cassée (gs_scars), dégâts sur la caisse, crime signalé (témoins)
function Racket.punish(src)
    local m = Gangs.online[src]
    local biz, b = Racket.businessAt(src)
    if not m or not m.gang or not biz then return false, 'Rien à faire ici.' end
    local g = Racket.grudge[biz]
    if not g or g.gang ~= m.gang or now() > g.untilAt then return false, 'Pas de compte à régler ici.' end
    Racket.grudge[biz] = nil
    save()
    local dmg = math.min(R().damage, (GetResourceState('gs_jobs') == 'started' and exports.gs_jobs:GetSocietyMoney(biz)) or 0)
    if dmg > 0 then society('RemoveSocietyMoney', biz, dmg) end
    if GetResourceState('gs_wanted') == 'started' then
        pcall(function() exports.gs_wanted:ReportCrime(src, 'racket', vec3(b.register.x, b.register.y, b.register.z)) end)
    end
    for _, s in ipairs(owners(biz)) do notify(s, ('Les %s ont saccagé le %s (%d $ de dégâts).'):format(gangLabel(m.gang), b.label, dmg), 'error') end
    TriggerEvent('gs_gangs:server:activity', m.gang, 'crime', GetEntityCoords(GetPlayerPed(src)), 'Racket et dégradation de commerce')
    return true, 'Message passé. La prochaine fois, il paiera.'
end

--- Prélèvements hebdomadaires
function Racket.tick()
    local changed = false
    for biz, d in pairs(Racket.deals) do
        if now() >= d.next then
            local label = (businesses()[biz] or {}).label or biz
            if society('RemoveSocietyMoney', biz, d.amount) then
                Store.addMoney(d.gang, d.amount)
                d.next = d.next + R().every * 86400
                notifyGang(d.gang, ('Protection du %s encaissée : +%d $.'):format(label, d.amount), 'success')
            else
                Racket.deals[biz] = nil
                Racket.grudge[biz] = { gang = d.gang, untilAt = now() + R().grudge }
                notifyGang(d.gang, ('Le %s n\'a pas payé cette semaine.'):format(label), 'warning')
            end
            changed = true
        end
    end
    for biz, g in pairs(Racket.grudge) do if now() > g.untilAt then Racket.grudge[biz] = nil changed = true end end
    if changed then save() end
end

--- Ce que le joueur peut faire à cette caisse (menu /racket)
function Racket.info(src)
    local biz, b = Racket.businessAt(src)
    if not biz then return nil end
    local m = Gangs.online[src]
    local d, g = Racket.deals[biz], Racket.grudge[biz]
    return {
        biz = biz, label = b.label, owner = isOwner(src, biz),
        deal = d and { gang = gangLabel(d.gang), amount = d.amount, mine = m and m.gang == d.gang, days = math.max(0, math.ceil((d.next - now()) / 86400)) } or nil,
        canDemand = m and m.gang and (m.grade or 0) >= R().minGrade and not d or false,
        canPunish = m and g and g.gang == m.gang and now() <= g.untilAt or false,
        min = R().min, max = R().max,
    }
end

lib.callback.register('gs_gangs:racket', function(src, action, a, b)
    if not Security:RateLimit(src, 'gs_gangs:racket', 4, 5000) then return false, 'Doucement.' end
    if action == 'info' then return Racket.info(src) end
    if action == 'demand' then return Racket.demand(src, a) end
    if action == 'answer' then return Racket.answer(src, tostring(a or ''), tostring(b or '')) end
    if action == 'stop' then return Racket.stop(src, tostring(a or '')) end
    if action == 'punish' then return Racket.punish(src) end
    return false, 'Action inconnue.'
end)

CreateThread(function()
    local raw = GetResourceKvpString('racket')
    if raw then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then Racket.deals, Racket.grudge = data.deals or {}, data.grudge or {} end
    end
    while true do Wait(300000) Racket.tick() end
end)
