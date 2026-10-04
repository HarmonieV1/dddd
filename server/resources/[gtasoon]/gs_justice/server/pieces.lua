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

lib.callback.register('gs_justice:pieces', function(src, action, caseId, a, b)
    if not Security:RateLimit(src, 'gs_justice:pieces', 6, 10000) then return false, 'Doucement.' end
    if action == 'list' then
        if not (onDuty(src, Config.JudgeJob) or onDuty(src, Config.LawyerJob) or onDuty(src, Config.PoliceJob)) then return false end
        return true, Pieces.list(tonumber(caseId) or 0)
    end
    if action == 'deposit' then return Pieces.deposit(src, caseId, a, b) end
    if action == 'decide' then return Pieces.decide(src, caseId, a, b == true) end
    return false, 'Action inconnue.'
end)
