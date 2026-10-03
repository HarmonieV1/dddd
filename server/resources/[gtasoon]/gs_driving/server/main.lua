-- gs_driving (serveur) : le code est tiré et corrigé ici (le client ne reçoit jamais les bonnes réponses) ; l'examen de conduite
-- est suivi ici (points dans l'ordre, vitesse et carrosserie relevées sur l'entité du véhicule d'examen).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs
local P = Config.Practical

Driving = { quiz = {}, exams = {}, lastTheory = {} }

local function atDesk(src) return Security:InRange(src, Config.Desk, Config.Range + 2.0) end
local function status(cid) return Store.get(cid) or 0 end

local function pay(src, price, reason)
    return Bridge:RemoveMoney(src, 'bank', price, reason) or Bridge:RemoveMoney(src, 'cash', price, reason)
end

local function grant(src, cid)
    Store.set(cid, 2)
    Bridge:SetLicence(src, 'driver', true)
    -- Carte « permis de conduire » (qbx_idcard) remise avec le permis : c'est le seul moyen de l'obtenir
    if GetResourceState('qbx_idcard') == 'started' and GetResourceState('ox_inventory') == 'started' then
        pcall(function()
            exports.ox_inventory:AddItem(src, 'driver_license', 1, exports.qbx_idcard:GetMetaLicense(src, { 'driver_license' }))
        end)
    end
end

--- À la connexion : un nouveau personnage perd le permis donné par défaut ; un ancien avec un véhicule le garde.
function Driving.onLoaded(src)
    if not Config.RequireExam then return end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    local st = Store.get(cid)
    if st == nil then
        if (Bridge:GetLicences(src) or {}).driver and Store.hasVehicle(cid) then Store.set(cid, 2) return end
        Store.set(cid, 0)
        st = 0
    end
    if st < 2 and (Bridge:GetLicences(src) or {}).driver then Bridge:SetLicence(src, 'driver', false) end
end
AddEventHandler('gs_bridge:server:playerLoaded', Driving.onLoaded)

lib.callback.register('gs_driving:info', function(src)
    if not Security:RateLimit(src, 'gs_driving:info', 6, 10000) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid or not atDesk(src) then return nil end
    return { status = status(cid), theoryPrice = Config.Theory.price, practicalPrice = P.price }
end)

--- Code : paie, tire N questions (ordre et questions aléatoires), n'envoie que les énoncés et les choix.
lib.callback.register('gs_driving:theoryStart', function(src)
    if not Security:RateLimit(src, 'gs_driving:theoryStart', 2, 10000) then return false, 'Doucement.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid or not atDesk(src) then return false, 'Présente-toi à l\'accueil.' end
    if status(cid) >= 1 then return false, 'Tu as déjà ton code.' end
    local wait = Driving.lastTheory[cid] and (Driving.lastTheory[cid] + Config.Theory.cooldown - os.time()) or 0
    if wait > 0 then return false, ('Tu pourras repasser le code dans %d min.'):format(math.ceil(wait / 60)) end
    if not pay(src, Config.Theory.price, 'code de la route') then return false, ('Code : %d $.'):format(Config.Theory.price) end
    local pool = {}
    for i = 1, #Config.Questions do pool[i] = i end
    for i = #pool, 2, -1 do local j = math.random(i) pool[i], pool[j] = pool[j], pool[i] end
    local picked, out = {}, {}
    for i = 1, math.min(Config.Theory.questions, #pool) do
        picked[i] = pool[i]
        local q = Config.Questions[pool[i]]
        out[i] = { q = q.q, options = q.options }
    end
    Driving.quiz[src] = { ids = picked, at = os.time() }
    Driving.lastTheory[cid] = os.time()
    return true, out
end)

lib.callback.register('gs_driving:theoryAnswer', function(src, answers)
    if not Security:RateLimit(src, 'gs_driving:theoryAnswer', 2, 10000) then return false, 'Doucement.' end
    local quiz = Driving.quiz[src]
    Driving.quiz[src] = nil
    if not quiz or type(answers) ~= 'table' then return false, 'Aucun examen en cours.' end
    local score = 0
    for i, id in ipairs(quiz.ids) do
        if tonumber(answers[i]) == Config.Questions[id].answer then score = score + 1 end
    end
    local cid = Bridge:GetIdentifier(src)
    if score >= Config.Theory.toPass then
        Store.set(cid, 1)
        return true, ('Code obtenu : %d / %d ! Inscris-toi à l\'examen de conduite.'):format(score, #quiz.ids)
    end
    return false, ('Raté : %d / %d (il en faut %d). Réessaie dans quelques minutes.'):format(score, #quiz.ids, Config.Theory.toPass)
end)

--- Conduite : paie, crée le véhicule d'examen, suit le parcours.
lib.callback.register('gs_driving:practicalStart', function(src)
    if not Security:RateLimit(src, 'gs_driving:practicalStart', 2, 10000) then return false, 'Doucement.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid or not atDesk(src) then return false, 'Présente-toi à l\'accueil.' end
    local st = status(cid)
    if st == 0 then return false, 'Il faut d\'abord réussir le code.' end
    if st >= 2 then return false, 'Tu as déjà ton permis.' end
    if Driving.exams[src] then return false, 'Examen déjà en cours.' end
    if not pay(src, P.price, 'examen de conduite') then return false, ('Examen : %d $.'):format(P.price) end
    local veh = Bridge:SpawnVehicle(src, P.model, 'automobile', P.spawn, P.spawn.w, P.plate, true)
    if not veh or veh == 0 then
        Bridge:AddMoney(src, 'bank', P.price, 'remboursement examen')
        return false, 'Véhicule indisponible, remboursé.'
    end
    Driving.exams[src] = { cid = cid, veh = veh, cp = 0, faults = 0, startedAt = os.time(), body = GetVehicleBodyHealth(veh), speeding = false }
    return true, NetworkGetNetworkIdFromEntity(veh)
end)

local function finish(src, passed, why)
    local e = Driving.exams[src]
    if not e then return end
    Driving.exams[src] = nil
    if DoesEntityExist(e.veh) then DeleteEntity(e.veh) end
    if passed then grant(src, e.cid) end
    TriggerClientEvent('gs_driving:client:end', src, passed, why)
end
Driving.finish = finish

local function fault(src, e, what)
    e.faults = e.faults + 1
    TriggerClientEvent('gs_driving:client:fault', src, what, e.faults, P.maxFaults)
    if e.faults > P.maxFaults then finish(src, false, 'Trop de fautes : examen raté.') end
end

--- Relevé serveur (1 fois / s) : vitesse, carrosserie, conducteur, délai.
function Driving.tick()
    for src, e in pairs(Driving.exams) do
        local ped = GetPlayerPed(src)
        if not DoesEntityExist(e.veh) then finish(src, false, 'Véhicule d\'examen perdu.')
        elseif os.time() - e.startedAt > P.timeout then finish(src, false, 'Temps écoulé.')
        elseif GetPedInVehicleSeat(e.veh, -1) ~= ped then
            e.out = (e.out or 0) + 1
            if e.out > 10 then finish(src, false, 'Tu as quitté le véhicule d\'examen.') end
        else
            e.out = 0
            local speed = GetEntitySpeed(e.veh)
            if speed > P.speedLimit * 1.1 then
                if not e.speeding then e.speeding = true fault(src, e, 'Excès de vitesse') end
            else e.speeding = false end
            local body = GetVehicleBodyHealth(e.veh)
            if Driving.exams[src] and e.body - body >= P.damageFault then e.body = body fault(src, e, 'Choc / dégâts') end
        end
    end
end

lib.callback.register('gs_driving:checkpoint', function(src)
    if not Security:RateLimit(src, 'gs_driving:checkpoint', 4, 5000) then return false end
    local e = Driving.exams[src]
    if not e then return false end
    local target = P.route[e.cp + 1]
    if not target or not Security:EntityInRange(src, e.veh, 6.0) then return false end
    if #(GetEntityCoords(e.veh) - target) > P.checkpointRadius + (P.snapMax or 0) + 4.0 then return false end -- point recollé à la route côté client
    e.cp = e.cp + 1
    if e.cp >= #P.route then
        finish(src, true, ('Permis obtenu avec %d faute(s). Bonne route !'):format(e.faults))
        return true, nil
    end
    return true, e.cp
end)

RegisterNetEvent('gs_driving:server:abandon', function()
    if Security:RateLimit(source, 'gs_driving:abandon', 2, 10000) then finish(source, false, 'Examen abandonné.') end
end)

--- Moniteur (métier) : délivre le permis à un candidat qui a son code, après un examen encadré en RP.
lib.callback.register('gs_driving:grant', function(src, target)
    if not Security:RateLimit(src, 'gs_driving:grant', 3, 10000) then return false, 'Doucement.' end
    target = tonumber(target)
    if not JobsApi:IsOnDutyAs(src, Config.Job) then return false, 'Réservé aux moniteurs en service.' end
    if not target or target == src or not Bridge:IsLoaded(target) then return false, 'Candidat introuvable.' end
    if not Security:PlayersInRange(src, target, 5.0) then return false, 'Trop loin.' end
    local cid = Bridge:GetIdentifier(target)
    if status(cid) == 0 then return false, 'Le candidat doit d\'abord réussir le code.' end
    if status(cid) >= 2 then return false, 'Il a déjà son permis.' end
    grant(target, cid)
    Bridge:Notify(target, 'Ton moniteur t\'a délivré le permis de conduire. Bonne route !', 'success')
    Security:LogStaff(('[Auto-école] %s délivre le permis à %s'):format(GetPlayerName(src) or src, GetPlayerName(target) or target), 'jobs')
    return true, 'Permis délivré.'
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) finish(src, false) Driving.quiz[src] = nil end)

-- V8 · Permis à points -----------------------------------------------------------------------------------------------

--- Solde de points (avec la récupération : +1 point par période sans infraction). nil = pas de permis.
function Driving.points(cid)
    if status(cid) < 2 then return nil end
    local pts, last = Store.points(cid)
    pts, last = pts or Config.Points.max, last or 0
    if pts < Config.Points.max and last > 0 then
        local gained = math.floor((os.time() - last) / (Config.Points.recoverDays * 86400))
        if gained > 0 then
            pts = math.min(Config.Points.max, pts + gained)
            Store.setPoints(cid, pts, pts >= Config.Points.max and 0 or (last + gained * Config.Points.recoverDays * 86400))
        end
    end
    return pts
end

--- Retire des points. À 0 : permis annulé (retour à l'auto-école). Retourne le nouveau solde (nil = pas de permis).
function Driving.removePoints(src, n, reason)
    n = math.floor(tonumber(n) or 0)
    local cid = Bridge:GetIdentifier(src)
    if not cid or n < 1 or n > Config.Points.maxPerOffense then return nil end
    local pts = Driving.points(cid)
    if not pts then return nil end
    pts = math.max(0, pts - n)
    Store.setPoints(cid, pts, os.time())
    if pts == 0 then
        Store.set(cid, 0)
        Bridge:SetLicence(src, 'driver', false)
        Bridge:Notify(src, 'Solde de points nul : permis annulé. Il faut repasser l\'auto-école (code et conduite).', 'error')
        if GetResourceState('gs_police') == 'started' then
            pcall(function() exports.gs_police:AddRecord(cid, 'Permis annulé (solde de points nul)', 0, 0, 'Préfecture') end)
        end
    else
        Bridge:Notify(src, ('Permis : -%d point(s) (%s). Solde : %d / %d.'):format(n, reason or 'infraction', pts, Config.Points.max), 'warning')
    end
    return pts
end

lib.callback.register('gs_driving:points', function(src)
    if not Security:RateLimit(src, 'gs_driving:points', 3, 5000) then return nil end
    local cid = Bridge:GetIdentifier(src)
    return cid and Driving.points(cid) or nil, Config.Points.max
end)

exports('RemovePoints', function(src, n, reason) return Driving.removePoints(src, n, reason) end)
exports('GetPoints', function(src) local cid = Bridge:GetIdentifier(src) return cid and Driving.points(cid) or nil end)

CreateThread(function()
    Store.init()
    while true do
        Wait(1000)
        if next(Driving.exams) then Driving.tick() end
    end
end)
