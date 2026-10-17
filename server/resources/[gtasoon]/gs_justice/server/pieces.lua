-- gs_justice (serveur) · V10.1 « Preuves recevables ». Pièces versées au dossier d'une affaire ouverte : la photo
-- quitte l'inventaire (sous la garde du tribunal), le scellé doit avoir été analysé au labo. Le juge tranche.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Pieces = {}

local function onDuty(src, job) return JobsApi:IsOnDutyAs(src, job) == true end
local function name(src) return Bridge:GetName(src) or tostring(src) end
local function inCourt(src) return Security:InRange(src, Config.Court, Config.CourtRadius) end
local function key(id) return 'pieces:' .. tostring(id) end

function Pieces.list(caseId)
    local ok, l = pcall(json.decode, GetResourceKvpString(key(caseId)) or '[]')
    return ok and type(l) == 'table' and l or {}
end
local function save(caseId, l) SetResourceKvp(key(caseId), json.encode(l)) end

local function evidence(kind, ref)
    if GetResourceState('gs_evidence') ~= 'started' then return nil end
    local ok, t = pcall(function() return exports.gs_evidence:CourtPiece(kind, ref) end)
    return ok and t or nil
end

--- Verser une pièce (police ou avocat en service, au tribunal, affaire ouverte)
function Pieces.deposit(src, caseId, kind, ref)
    if not (onDuty(src, Config.PoliceJob) or onDuty(src, Config.LawyerJob)) then return false, 'Réservé à la police et aux avocats en service.' end
    if not inCourt(src) then return false, 'Les pièces se versent au tribunal.' end
    local case = Store.get(tonumber(caseId) or 0)
    if not case or case.status ~= 'open' then return false, 'Affaire introuvable ou déjà jugée.' end
    local l = Pieces.list(case.id)
    if #l >= Config.Pieces.max then return false, 'Dossier complet.' end
    ref = tostring(ref or '')
    for _, p in ipairs(l) do if p.kind == kind and p.ref == ref then return false, 'Pièce déjà versée.' end end
    local text = (kind == 'photo' or kind == 'seal') and evidence(kind, ref)
    if not text then return false, kind == 'seal' and 'Scellé introuvable ou pas encore analysé au labo.' or 'Pièce illisible.' end
    if kind == 'photo' and not Bridge:RemoveItem(src, Config.Pieces.photoItem, 1, { photo = ref }) then return false, 'Il faut avoir la photo sur toi.' end
    l[#l + 1] = { id = #l + 1, kind = kind, ref = ref, text = text:sub(1, 300), by = name(src), status = 'pending' }
    save(case.id, l)
    return true, ('Pièce n°%d versée au dossier #%d.'):format(#l, case.id)
end

--- Le juge retient ou écarte une pièce
function Pieces.decide(src, caseId, pieceId, retain)
    if not onDuty(src, Config.JudgeJob) then return false, 'Réservé aux juges en service.' end
    local case = Store.get(tonumber(caseId) or 0)
    if not case or case.status ~= 'open' then return false, 'Affaire introuvable ou déjà jugée.' end
    local l = Pieces.list(case.id)
    local p = l[tonumber(pieceId) or 0]
    if not p then return false, 'Pièce introuvable.' end
    p.status = retain and 'retained' or 'rejected'
    save(case.id, l)
    return true, retain and ('Pièce n°%d retenue.'):format(p.id) or ('Pièce n°%d écartée.'):format(p.id)
end

function Pieces.retained(caseId)
    local n = 0
    for _, p in ipairs(Pieces.list(caseId)) do if p.status == 'retained' then n = n + 1 end end
    return n
end

--- V12.65 · Témoin PNJ à la barre : le prochain témoignage pas encore entendu dans cette affaire (gs_wanted), versé comme pièce
function Pieces.witness(src, caseId)
    if not (onDuty(src, Config.JudgeJob) or onDuty(src, Config.LawyerJob) or onDuty(src, Config.PoliceJob)) then return false, 'Réservé au juge, aux avocats et à la police en service.' end
    if not inCourt(src) then return false, 'Les témoins se citent au tribunal.' end
    local case = Store.get(tonumber(caseId) or 0)
    if not case or case.status ~= 'open' then return false, 'Affaire introuvable ou déjà jugée.' end
    if GetResourceState('gs_wanted') ~= 'started' then return false, 'Aucun témoin disponible.' end
    local okT, list = pcall(function() return exports.gs_wanted:Testimonies(case.defendant) end)
    list = okT and type(list) == 'table' and list or {}
    local l = Pieces.list(case.id)
    local heard = {}
    for _, p in ipairs(l) do if p.kind == 'witness' then heard[p.ref] = true end end
    local pick
    for _, t in ipairs(list) do if not heard[tostring(t.at)] then pick = t break end end
    if not pick then return false, #list == 0 and 'Aucun témoin ne s\'est manifesté contre ce prévenu (aucun crime signalé ces 14 derniers jours).' or 'Tous les témoins ont déjà été entendus.' end
    if #l >= Config.Pieces.max then return false, 'Dossier complet.' end
    local okS, speech = pcall(function() return exports.gs_wanted:TestimonySpeech(pick) end)
    speech = okS and speech or 'Un passant témoigne.'
    l[#l + 1] = { id = #l + 1, kind = 'witness', ref = tostring(pick.at), text = speech:sub(1, 300), by = 'témoin cité par ' .. name(src), status = 'pending' }
    save(case.id, l)
    -- tout le monde dans la salle entend le témoin ; celui qui l'a cité fait venir le PNJ à la barre
    for _, id in ipairs(GetPlayers()) do
        local p = tonumber(id)
        if inCourt(p) then TriggerClientEvent('gs_justice:client:witness', p, speech, p == src, Config.Witness) end
    end
    Security:LogStaff(('[Tribunal] affaire #%s : témoin PNJ cité par %s'):format(case.id, name(src)), 'jobs')
    return true, ('Témoin entendu : pièce n°%d versée au dossier.'):format(#l)
end

lib.callback.register('gs_justice:pieces', function(src, action, caseId, a, b)
    if not Security:RateLimit(src, 'gs_justice:pieces', 6, 10000) then return false, 'Doucement.' end
    if action == 'list' then
        if not (onDuty(src, Config.JudgeJob) or onDuty(src, Config.LawyerJob) or onDuty(src, Config.PoliceJob)) then return false end
        return true, Pieces.list(tonumber(caseId) or 0)
    end
    if action == 'deposit' then return Pieces.deposit(src, caseId, a, b) end
    if action == 'decide' then return Pieces.decide(src, caseId, a, b == true) end
    if action == 'witness' then return Pieces.witness(src, caseId) end -- V12.65
    return false, 'Action inconnue.'
end)
