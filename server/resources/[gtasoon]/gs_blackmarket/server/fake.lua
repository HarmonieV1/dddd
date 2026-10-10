-- gs_blackmarket (serveur) · V12 « Le marché des faux papiers ». À l'achat, le faux papier reçoit une identité inventée
-- (metadata). L'utiliser le « présente » : pendant `Config.Fake.minutes`, un contrôle F4 loin du commissariat montre la
-- fausse identité (et les permis qu'il prétend) ; au commissariat, le scanner le démasque (gs_police). Jamais d'identité réelle.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Fake = {}

local function pick(l) return l[math.random(#l)] end

--- Metadata d'un faux papier neuf
function Fake.metadata(src, kind)
    local F = Config.Fake
    local gender = Bridge:GetGender(src)
    return { fake = kind, fakeName = ('%s %s'):format(pick(F.first), pick(F.last)),
        fakeBirth = ('%02d/%02d/%d'):format(math.random(1, 28), math.random(1, 12), math.random(1975, 2004)),
        sex = gender == 'female' and 'F' or 'M', description = 'Papier au nom de quelqu\'un d\'autre. Double-clic : le présenter.' }
end

--- Présentation (double-clic sur le papier) : état public 10 min, visible des joueurs à côté
function Fake.present(src, item, slot)
    local okS, data = pcall(function() return exports.ox_inventory:GetSlot(src, slot) end) -- [API] ox_inventory
    if not okS or not data or data.name ~= item or not data.metadata or not data.metadata.fake then return false, 'Papier introuvable.' end
    local m = data.metadata
    local st = Player(src).state
    local cur = st.gsFake
    if not cur or (cur.untilTs or 0) < os.time() or cur.name ~= m.fakeName then cur = { name = m.fakeName, birth = m.fakeBirth, kinds = {} } end
    cur.kinds[m.fake] = true
    cur.untilTs = os.time() + Config.Fake.minutes * 60
    st:set('gsFake', cur, true)
    local label = ({ id = 'une carte d\'identité', driver = 'un permis de conduire', weapon = 'un permis de port d\'arme' })[m.fake] or 'un papier'
    local me = GetEntityCoords(GetPlayerPed(src))
    for _, pid in ipairs(GetPlayers()) do
        local s = tonumber(pid)
        if s ~= src and Security:PlayersInRange(src, s, 5.0) then
            Bridge:Notify(s, ('%s présente %s : %s, né(e) le %s.'):format(Bridge:GetName(src) or '?', label, m.fakeName, m.fakeBirth or '?'), 'inform')
        end
    end
    return true, ('Tu présentes %s au nom de %s (valable %d min pour les contrôles).'):format(label, m.fakeName, Config.Fake.minutes)
end

RegisterNetEvent('gs_blackmarket:server:presentFake', function(item, slot)
    local src = source
    if not Security:RateLimit(src, 'gs_blackmarket:fake', 3, 10000) then return end
    if type(item) ~= 'string' or not tonumber(slot) then return end
    local ok, msg = Fake.present(src, item, tonumber(slot))
    Bridge:Notify(src, msg, ok and 'success' or 'error')
end)
