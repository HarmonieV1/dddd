-- gs_evidence (serveur) · V10.1 « Chantage ». Une photo où l'on voit quelqu'un peut servir à le faire chanter, face à
-- face. Payer = la photo lui est remise (il en fait ce qu'il veut). Refuser (ou ne pas répondre) = la photo « fuite » :
-- brève Weazel et rumeur. Chaque photo ne sert qu'une fois ; le serveur vérifie que la cible est bien sur le cliché.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local C, B = Config.Camera, Config.Blackmail

Blackmail = { pending = {} } -- [cible] = { from, photo, amount, expires }

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end

local function hasPhoto(src, id)
    local ok, n = pcall(function() return exports.ox_inventory:GetItemCount(src, C.photo, { photo = id }) end) -- [API] ox_inventory
    if ok and type(n) == 'number' then return n > 0 end
    return Bridge:GetItemCount(src, C.photo) > 0
end

local function onPhoto(rec, cid)
    for _, s in ipairs(rec.subjects or {}) do if s.cid == cid then return true end end
    return false
end

local function leak(id, rec)
    local text = ('Une photo compromettante circule : %s (%s).'):format(rec.text or '?', rec.place or 'Los Santos')
    if started('gs_social') then pcall(function() exports.gs_social:Newsroom('chantage_' .. id, text) end) end
    if started('gs_rumors') then pcall(function() exports.gs_rumors:Add('Il paraît qu\'une photo gênante circule…', text) end) end
end

--- Le maître chanteur montre la photo à la personne qu'on y voit et fixe son prix
function Blackmail.start(src, photoId, target, amount)
    photoId, target, amount = tostring(photoId or ''), tonumber(target), math.floor(tonumber(amount) or 0)
    if not target or target == src or not Bridge:IsLoaded(target) then return false, 'Personne ici.' end
    if amount < B.min or amount > B.max then return false, ('Montant entre %d et %d $.'):format(B.min, B.max) end
    if not Security:PlayersInRange(src, target, B.range) then return false, 'Approche-toi.' end
    if Blackmail.pending[target] and Blackmail.pending[target].expires > now() then return false, 'Il a déjà quelqu\'un sur le dos.' end
    if not hasPhoto(src, photoId) then return false, 'Il faut avoir la photo sur toi.' end
    local rec = Photo.get(photoId)
    if not rec then return false, 'Photo voilée.' end
    if rec.used then return false, 'Cette photo a déjà servi.' end
    if not onPhoto(rec, Bridge:GetIdentifier(target)) then return false, 'On ne le reconnaît pas sur cette photo.' end
    Blackmail.pending[target] = { from = src, photo = photoId, amount = amount, expires = now() + B.answerSeconds }
    TriggerClientEvent('gs_evidence:client:blackmail', target, amount, rec.text or '', rec.image, B.answerSeconds)
    return true, 'Photo montrée. Il a ' .. B.answerSeconds .. ' s pour payer.'
end

local function close(target, pay)
    local p = Blackmail.pending[target]
    if not p then return false, 'Plus rien à payer.' end
    Blackmail.pending[target] = nil
    local rec = Photo.get(p.photo)
    if not rec or rec.used then return false, 'La photo a disparu.' end
    local src = p.from
    if pay and p.expires >= now() and Bridge:IsLoaded(src) then
        if not hasPhoto(src, p.photo) then return false, 'Il n\'a plus la photo.' end
        local acc = Bridge:GetMoney(target, 'cash') >= p.amount and 'cash' or 'bank'
        if not Bridge:RemoveMoney(target, acc, p.amount, 'chantage') then
            pay = false -- pas les moyens : la photo fuite
        else
            Bridge:RemoveItem(src, C.photo, 1, { photo = p.photo })
            Bridge:AddMoney(src, 'cash', p.amount, 'chantage')
            Bridge:AddItem(target, C.photo, 1, { photo = p.photo, label = rec.label, description = rec.text, image = rec.image })
            rec.used = true
            SetResourceKvp('gs_photo:' .. p.photo, json.encode(rec))
            Bridge:Notify(src, ('Il a payé %d $. La photo est à lui.'):format(p.amount), 'success')
            Security:LogStaff(('[Chantage] %s a payé %d $ à %s'):format(Bridge:GetName(target) or target, p.amount, Bridge:GetName(src) or src))
            return true, 'Tu as payé. La photo est à toi.'
        end
    end
    rec.used = true
    SetResourceKvp('gs_photo:' .. p.photo, json.encode(rec))
    leak(p.photo, rec)
    if Bridge:IsLoaded(src) then Bridge:Notify(src, 'Il a refusé : la photo a fuité dans la presse.', 'warning') end
    return true, 'Tu as refusé : la photo circule déjà…'
end
Blackmail.answer = close

--- Sans réponse à temps : la photo fuite
function Blackmail.tick()
    for target, p in pairs(Blackmail.pending) do
        if p.expires < now() then close(target, false) end
    end
end

lib.callback.register('gs_evidence:blackmail', function(src, action, a, b, c)
    if not Security:RateLimit(src, 'gs_evidence:blackmail', 3, 10000) then return false, 'Doucement.' end
    if action == 'start' then return Blackmail.start(src, a, b, c) end
    if action == 'answer' then return close(src, a == true) end
    return false
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    if Blackmail.pending[src] then close(src, false) end -- la cible fuit : la photo aussi
    for target, p in pairs(Blackmail.pending) do if p.from == src then Blackmail.pending[target] = nil end end
end)

CreateThread(function()
    while true do Wait(5000) Blackmail.tick() end
end)
