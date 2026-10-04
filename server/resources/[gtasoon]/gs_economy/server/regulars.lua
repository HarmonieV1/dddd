-- gs_economy (serveur) · V10 « Les commerçants se souviennent ». Par personnage et par magasin : jours de visite
-- (habitué = remise + salutation) et interdiction après un braquage à visage découvert. KVP, rien côté client.
local Bridge = exports.gs_bridge
local G = Config.Regulars

Regulars = {}

local function key(cid) return 'reg:' .. cid end
local function loadReg(cid)
    local ok, t = pcall(json.decode, GetResourceKvpString(key(cid)) or '{}')
    return ok and type(t) == 'table' and t or {}
end
local function saveReg(cid, t) SetResourceKvp(key(cid), json.encode(t)) end
local function today() return os.date('%Y-%m-%d') end

--- Achat : une visite comptée par jour et par magasin
function Regulars.visit(src, idx)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return 0 end
    local t = loadReg(cid)
    local s = t[tostring(idx)] or { n = 0 }
    if s.day ~= today() then s.n, s.day = s.n + 1, today() end
    t[tostring(idx)] = s
    saveReg(cid, t)
    return s.n
end

function Regulars.isRegular(src, idx)
    local cid = Bridge:GetIdentifier(src)
    local s = cid and loadReg(cid)[tostring(idx)]
    return s ~= nil and (s.n or 0) >= G.visits
end

--- Interdit au comptoir ? retourne le message du vendeur ou nil
function Regulars.banned(src, idx)
    local cid = Bridge:GetIdentifier(src)
    local s = cid and loadReg(cid)[tostring(idx)]
    if s and s.ban and os.time() < s.ban then return '« Toi, je te reconnais. Tu m\'as braqué. Dehors, ou j\'appelle les flics ! »' end
    return nil
end

--- Remise totale (réputation + habitué), plafonnée
function Regulars.discount(src, idx, base)
    local d = (base or 0) + (Regulars.isRegular(src, idx) and G.discount or 0)
    return math.min(G.maxDiscount, d)
end

--- Braquage d'un magasin : si le braqueur avait le visage découvert, le vendeur s'en souvient
function Regulars.robbed(src, coords)
    local ped = GetPlayerPed(src)
    if ped == 0 or GetPedDrawableVariation(ped, 1) ~= 0 then return false end -- masqué : pas reconnu
    local best, bd
    for i, sh in ipairs(Config.Shops) do
        local c = sh.clerk or sh.coords
        local d = c and #(vec3(c.x, c.y, c.z) - vec3(coords.x, coords.y, coords.z))
        if d and d <= G.radius and (not bd or d < bd) then best, bd = i, d end
    end
    if not best then return false end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false end
    local t = loadReg(cid)
    t[tostring(best)] = { n = 0, ban = os.time() + G.banHours * 3600 } -- plus du tout un habitué
    saveReg(cid, t)
    return best
end

AddEventHandler('gs_wanted:server:crime', function(src, crimeType, coords)
    if G.crimes[crimeType] and coords then Regulars.robbed(src, coords) end
end)
