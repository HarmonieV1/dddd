-- gs_radio (serveur) : qui a le droit d'entrer sur un canal réservé. La vérification est faite par pma-voice lui-même
-- (addChannelCheck) : un client modifié ne peut pas écouter la police ou un autre gang, quel que soit le menu utilisé.
local Bridge = exports.gs_bridge
local Security = exports.gs_security

Radio = { gangChannels = {}, gangOfChannel = {} }

local function started(res) return GetResourceState(res) == 'started' end

local function hash(name)
    local h = 0
    for i = 1, #name do h = (h * 31 + name:byte(i)) % 1000003 end
    return h
end

--- Recalcule le canal de chaque gang (hash du nom, décalé si déjà pris : stable tant que les gangs ne changent pas).
function Radio.refreshGangs()
    Radio.gangChannels, Radio.gangOfChannel = {}, {}
    if not started('gs_gangs') then return end
    local names = {}
    for _, g in ipairs(exports.gs_gangs:ListGangs() or {}) do names[#names + 1] = g.name end
    table.sort(names)
    local lo, hi = Config.GangRange[1], Config.GangRange[2]
    local size = hi - lo + 1
    for _, name in ipairs(names) do
        local ch = lo + hash(name) % size
        for _ = 1, size do
            if not Radio.gangOfChannel[ch] then break end
            ch = ch + 1
            if ch > hi then ch = lo end
        end
        Radio.gangChannels[name], Radio.gangOfChannel[ch] = ch, name
    end
end

local function jobAllowed(src, rule)
    local job = Bridge:GetJob(src)
    if not job then return false end
    for _, name in ipairs(rule.jobs) do
        if job.name == name then return not rule.onDuty or job.onduty == true end
    end
    return false
end

--- true si src peut entrer sur ce canal.
function Radio.allowed(src, channel)
    channel = tonumber(channel)
    if not channel or channel <= 0 or channel > Config.MaxChannel then return false end
    local rule = Config.JobChannels[channel]
    if rule then return jobAllowed(src, rule) end
    local lo, hi = Config.GangRange[1], Config.GangRange[2]
    if channel >= lo and channel <= hi and channel == math.floor(channel) then
        local owner = Radio.gangOfChannel[channel]
        if not owner then return false end -- canal de gang libre : réservé quand même (pas d'écoute d'un futur gang)
        local gang = started('gs_gangs') and exports.gs_gangs:GetGang(src)
        return gang == owner
    end
    return true
end

--- Canaux proposés au joueur (menu) : ceux de son métier, celui de son gang.
lib.callback.register('gs_radio:presets', function(src)
    if not Security:RateLimit(src, 'gs_radio:presets', 5, 10000) then return nil end
    local list = {}
    for ch, rule in pairs(Config.JobChannels) do
        if jobAllowed(src, rule) then list[#list + 1] = { channel = ch, label = rule.label } end
    end
    table.sort(list, function(a, b) return a.channel < b.channel end)
    local gang = started('gs_gangs') and exports.gs_gangs:GetGang(src)
    if gang and Radio.gangChannels[gang] then list[#list + 1] = { channel = Radio.gangChannels[gang], label = 'Gang (privé)', gang = true } end
    return list
end)

--- Qui est sur mon canal (seulement si j'y suis moi-même). [API] pma-voice getPlayersInRadioChannel
lib.callback.register('gs_radio:members', function(src)
    if not Security:RateLimit(src, 'gs_radio:members', 5, 10000) then return nil end
    local channel = Player(src).state.radioChannel
    if not channel or channel == 0 or not started('pma-voice') then return nil end
    local list = {}
    for member, talking in pairs(exports['pma-voice']:getPlayersInRadioChannel(channel) or {}) do
        list[#list + 1] = { name = Bridge:GetName(member) or GetPlayerName(member) or '?', talking = talking == true, me = member == src }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end)

lib.callback.register('gs_radio:canJoin', function(src, channel)
    if not Security:RateLimit(src, 'gs_radio:canJoin', 10, 10000) then return false end
    return Radio.allowed(src, channel)
end)

CreateThread(function()
    Wait(2000)
    Radio.refreshGangs()
    if not started('pma-voice') then return print('[gs_radio] pma-voice absent : canaux non protégés') end
    for ch in pairs(Config.JobChannels) do
        exports['pma-voice']:addChannelCheck(ch, function(src) return Radio.allowed(src, ch) end) -- [API] pma-voice
    end
    for ch = Config.GangRange[1], Config.GangRange[2] do
        exports['pma-voice']:addChannelCheck(ch, function(src) return Radio.allowed(src, ch) end)
    end
    while true do
        Wait(300000) -- nouveaux gangs créés en jeu
        Radio.refreshGangs()
    end
end)

exports('GetGangChannel', function(gang) return Radio.gangChannels[gang] end)
