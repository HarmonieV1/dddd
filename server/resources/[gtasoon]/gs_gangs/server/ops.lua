-- gs_gangs (serveur) · V12 « La guerre de l'information ». Deux opérations payées par la caisse du gang (grade ≥ minGrade) :
--   jam     : brouiller les caméras (gs_cctv) autour du membre pendant `minutes`
--   scanner : pirater le scanner police : pendant `minutes`, les membres en ligne reçoivent les appels (gs_wanted, 911)
-- Chaque opération laisse une trace : la police la remonte depuis l'ordinateur du commissariat (gs_cctv), après un délai.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Ops = { last = {} } -- last[gang .. ':' .. kind] = os.time()

local function started(r) return GetResourceState(r) == 'started' end
local function member(src) local m = Gangs.online[src] return m and m.gang and m or nil end

function Ops.run(src, kind)
    local def = Config.Ops[kind]
    if not def then return false, 'Opération inconnue.' end
    local m = member(src)
    if not m then return false, 'Tu n\'es dans aucun gang.' end
    if m.grade < def.minGrade then return false, ('Grade %d minimum.'):format(def.minGrade) end
    local key = m.gang .. ':' .. kind
    local last = Ops.last[key]
    local left = last and (last + def.cooldown - os.time()) or 0
    if left > 0 then return false, ('Trop tôt : encore %d min.'):format(math.ceil(left / 60)) end
    local c = GetEntityCoords(GetPlayerPed(src))
    local label = Gangs.list[m.gang] and Gangs.list[m.gang].label or m.gang
    if kind == 'jam' then
        if not started('gs_cctv') then return false, 'Rien à brouiller.' end
        if not Store.removeMoney(m.gang, def.cost) then return false, ('Caisse insuffisante : %d $.'):format(def.cost) end
        local n = exports.gs_cctv:BlindArea(c.x, c.y, def.radius, def.minutes)
        pcall(function() exports.gs_cctv:Trace('jam', label, c) end)
        Ops.last[key] = os.time()
        Security:LogStaff(('[Gang] %s brouille %d caméra(s) (%s)'):format(label, n, GetPlayerName(src) or src), 'jobs')
        return true, ('%d caméra(s) aveugles pendant %d min. La police pourra remonter la source.'):format(n, def.minutes)
    elseif kind == 'scanner' then
        if not Store.removeMoney(m.gang, def.cost) then return false, ('Caisse insuffisante : %d $.'):format(def.cost) end
        GlobalState.gsScanner = { gang = m.gang, untilTs = os.time() + def.minutes * 60 }
        pcall(function() exports.gs_cctv:Trace('scanner', label, c) end)
        Ops.last[key] = os.time()
        for s, mm in pairs(Gangs.online) do if mm.gang == m.gang then Bridge:Notify(s, ('Scanner police piraté : vous entendez leurs appels pendant %d min.'):format(def.minutes), 'warning') end end
        Security:LogStaff(('[Gang] %s pirate le scanner police (%s)'):format(label, GetPlayerName(src) or src), 'jobs')
        return true, ('Scanner piraté pour %d min.'):format(def.minutes)
    end
    return false
end

lib.callback.register('gs_gangs:op', function(src, kind)
    if not Security:RateLimit(src, 'gs_gangs:op', 2, 10000) then return false, 'Doucement.' end
    return Ops.run(src, tostring(kind))
end)

--- Membres en ligne d'un gang (sources) [API]
exports('MembersOnline', function(gang)
    local l = {}
    for s, m in pairs(Gangs.online) do if m.gang == gang then l[#l + 1] = s end end
    return l
end)
--- Message à tous les membres en ligne [API]
exports('NotifyGang', function(gang, msg, t)
    local n = 0
    for s, m in pairs(Gangs.online) do if m.gang == gang then Bridge:Notify(s, msg, t or 'inform') n = n + 1 end end
    return n
end)
--- Sources qui écoutent le scanner police piraté en ce moment (gs_wanted, gs_phone) [API]
exports('ScannerListeners', function()
    local s = GlobalState.gsScanner
    if type(s) ~= 'table' or (s.untilTs or 0) < os.time() then return {} end
    local l = {}
    for src, m in pairs(Gangs.online) do if m.gang == s.gang then l[#l + 1] = src end end
    return l
end)
