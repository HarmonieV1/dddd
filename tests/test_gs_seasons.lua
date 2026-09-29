-- Tests gs_seasons : saison en cours (dates), points depuis l'XP, paliers (atteints, gratuit / premium, une fois, rollback),
-- premium via la boutique, titre, palmarès archivé une fois.
dofile('tests/mock.lua')
-- os.time du mock ignore les dates : on remet le calcul d'une date (jours depuis 1970, algorithme civil)
local mockTime = os.time
os.time = function(t)
    if not t then return mockTime() end
    local y, m = t.year, t.month
    if m <= 2 then y = y - 1 end
    local era = (y >= 0 and y or y - 399) // 400
    local yoe = y - era * 400
    local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + t.day - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return (era * 146097 + doe - 719468) * 86400 + (t.hour or 12) * 3600
end
local R = 'server/resources/[gtasoon]/'
local unlocked = {}
provide('gs_store', { UnlockOutfit = function(cid, id) unlocked[#unlocked + 1] = id return true end })
provide('gs_social', { GetHandle = function() return nil end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_seasons', { R .. 'gs_seasons/shared/config.lua' })
local rows, hall = {}, {}
local function key(s, c) return s .. '|' .. c end
Store = { init = function() end,
    get = function(s, c) local r = rows[key(s, c)] or { points = 0, premium = false, claimed = {}, title = '' } local cl = {} for k in pairs(r.claimed) do cl[k] = true end return { points = r.points, premium = r.premium, claimed = cl, title = r.title } end,
    addPoints = function(s, c, n, p) local k = key(s, c) rows[k] = rows[k] or { points = 0, premium = false, claimed = {}, title = '' } rows[k].points = rows[k].points + p rows[k].name = n end,
    setPremium = function(s, c) local k = key(s, c) rows[k] = rows[k] or { points = 0, premium = false, claimed = {}, title = '' } rows[k].premium = true end,
    saveClaims = function(s, c, cl, t) local k = key(s, c) rows[k] = rows[k] or { points = 0, premium = false, claimed = {}, title = '' } local copy = {} for x in pairs(cl) do copy[x] = true end rows[k].claimed = copy rows[k].title = t or '' end,
    top = function(s) local l = {} for k, r in pairs(rows) do if k:sub(1, #s + 1) == s .. '|' and r.points > 0 then l[#l + 1] = { name = r.name, points = r.points } end end table.sort(l, function(a, b) return a.points > b.points end) return l end,
    hallHas = function(s) for _, h in ipairs(hall) do if h.season == s then return true end end return false end,
    hallAdd = function(s, rank, n, p) hall[#hall + 1] = { season = s, rank = rank, name = n, points = p } end,
    hall = function() return hall end }
loadResource('gs_seasons', { R .. 'gs_seasons/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

-- Dates
local s1 = os.time({ year = 2026, month = 9, day = 28, hour = 0 })
check('avant la saison 1 : aucune', Seasons.current(s1 - 10) == nil)
check('pendant : saison 1', Seasons.current(s1 + 86400).id == 's1')
check('après 8 semaines : plus la 1', (Seasons.current(s1 + 8 * 7 * 86400 + 10) or {}).id ~= 's1')

-- On fige « maintenant » dans la saison 1
local now = s1 + 3 * 86400
Seasons.current = (function(f) return function(t) return f(t or now) end end)(Seasons.current)
join(1, 'CID1', 'Joueur Un', vec3(0.0, 0.0, 0.0))
TriggerEvent('gs_quests:server:xp', 1, 1500, 'mission')
local d = cb('gs_seasons:info', 1); step()
check('points de saison depuis l\'XP', d and d.points == 1500 and d.tiers[1].reached and not d.tiers[2].reached)
local ok, msg = cb('gs_seasons:claim', 1, 2, 'free'); step()
check('palier non atteint', not ok)
ok = cb('gs_seasons:claim', 1, 1, 'premium'); step()
check('premium sans pass : refusé', not ok)
ok = cb('gs_seasons:claim', 1, 1, 'free'); step()
check('palier 1 gratuit : 500 $', ok and W.players[1].money.bank == 500)
ok = cb('gs_seasons:claim', 1, 1, 'free'); step()
check('une seule fois', not ok and W.players[1].money.bank == 500)
check('boutique : pass premium', getExport('gs_seasons', 'GrantPremium')('CID1'))
ok, msg = cb('gs_seasons:claim', 1, 1, 'premium'); step()
check('premium : titre', ok and getExport('gs_seasons', 'GetTitle')(1) == 'Pionnier de la saison')
TriggerEvent('gs_quests:server:xp', 1, 1000)
ok = cb('gs_seasons:claim', 1, 2, 'premium'); step()
check('premium palier 2 : tenue débloquée', ok and unlocked[1] == 'season1_bomber')
W.players[1].full = true
ok = cb('gs_seasons:claim', 1, 2, 'free'); step()
check('sac plein : récompense non marquée', not ok and not Store.get('s1', 'CID1').claimed.f2)
W.players[1].full = nil
ok = cb('gs_seasons:claim', 1, 99, 'free'); step()
check('palier inconnu', not ok)

-- Palmarès : archivé une fois à la fin
join(2, 'CID2', 'Joueur Deux', vec3(0.0, 0.0, 0.0))
TriggerEvent('gs_quests:server:xp', 2, 9000)
Seasons.archive(s1 + 8 * 7 * 86400 + 5)
check('palmarès : podium archivé', #hall == 2 and hall[1].name == 'Joueur D.' and hall[1].rank == 1)
Seasons.archive(s1 + 8 * 7 * 86400 + 99)
check('palmarès : une seule fois', #hall == 2)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
