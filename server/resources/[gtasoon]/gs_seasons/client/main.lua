-- gs_seasons (client) : /saison → pass (paliers gratuits / premium, récupération), classement, palmarès.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function rewardLabel(r)
    if not r then return '—' end
    if r.cash then return r.cash .. ' $' end
    if r.item then return ('%d × %s'):format(r.count or 1, r.item) end
    if r.title then return 'Titre « ' .. r.title .. ' »' end
    if r.outfit then return 'Tenue exclusive' end
    return '?'
end

local function open()
    local d = lib.callback.await('gs_seasons:info', false)
    if not d then return end
    local options = {}
    if d.none then
        options[1] = { title = 'Pas de saison en cours', description = 'La prochaine arrive bientôt.', icon = 'hourglass', readOnly = true }
    else
        options[#options + 1] = { title = d.season.label, description = ('%s\n%d jours restants'):format(d.season.theme, d.daysLeft), icon = 'sun', readOnly = true }
        options[#options + 1] = { title = ('%d points · palier %d / %d'):format(d.points, math.min(#d.tiers, d.points // d.perTier), #d.tiers),
            progress = math.floor((d.points % d.perTier) / d.perTier * 100), colorScheme = 'pink', icon = 'star', readOnly = true,
            description = (d.premium and 'Piste premium active' or 'Piste premium : pass de saison (boutique)') .. (d.title ~= '' and ('\nTitre : ' .. d.title) or '') }
        for i, t in ipairs(d.tiers) do
            options[#options + 1] = { title = ('Palier %d · gratuit : %s'):format(i, rewardLabel(t.free)), icon = t.freeClaimed and 'circle-check' or 'gift',
                disabled = not t.reached or t.freeClaimed, onSelect = function() notify(lib.callback.await('gs_seasons:claim', false, i, 'free')) open() end }
            options[#options + 1] = { title = ('Palier %d · premium : %s'):format(i, rewardLabel(t.premium)), icon = t.premiumClaimed and 'circle-check' or 'crown',
                iconColor = '#ffd23f', disabled = not t.reached or t.premiumClaimed or not d.premium,
                onSelect = function() notify(lib.callback.await('gs_seasons:claim', false, i, 'premium')) open() end }
        end
        for i, r in ipairs(d.top) do options[#options + 1] = { title = ('%d. %s'):format(i, r.name), description = r.points .. ' points', icon = 'ranking-star', readOnly = true } end
    end
    for _, h in ipairs(d.hall) do options[#options + 1] = { title = ('Palmarès %s · %d. %s'):format(h.season, h.rank, h.name), description = h.points .. ' points', icon = 'trophy', readOnly = true } end
    lib.registerContext({ id = 'gs_seasons', title = 'Pass de saison', options = options })
    lib.showContext('gs_seasons')
end

RegisterCommand('saison', open, false)
