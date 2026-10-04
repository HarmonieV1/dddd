-- gs_roadside (serveur) · V8 « Halloween sur la route » : activation par date (ou staff), chasse aux 13 citrouilles.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local H = Config.Halloween

Halloween = { forced = nil } -- nil = selon la date ; true / false = forcé par le staff

function Halloween.inWindow(d)
    d = d or os.date('*t')
    local md = d.month * 100 + d.day
    local from, to = H.from[1] * 100 + H.from[2], H.to[1] * 100 + H.to[2]
    if from <= to then return md >= from and md <= to end
    return md >= from or md <= to
end

function Halloween.refresh()
    local on
    if Halloween.forced ~= nil then on = Halloween.forced else on = Halloween.inWindow() end
    if (GlobalState.gsHalloween == true) ~= on then
        GlobalState.gsHalloween = on
        if on and GetResourceState('gs_social') == 'started' then
            pcall(function() exports.gs_social:Newsroom('flash', 'Halloween sur la route : des choses étranges sur les routes du comté… et 13 citrouilles cachées.') end)
        end
    end
end

--- Citrouille ramassée (une fois chacune par personnage). À 13 : récompense.
function Halloween.pumpkin(src, i)
    if GlobalState.gsHalloween ~= true then return false, 'Ce n\'est pas la saison.' end
    i = tonumber(i)
    local c = i and H.pumpkins[i]
    local cid = Bridge:GetIdentifier(src)
    if not c or not cid then return false end
    if not Security:InRange(src, c, 4.0) then return false, 'Trop loin.' end
    local seen = Store.list(cid)
    if seen['pumpkin' .. i] then return false, 'Déjà ramassée.' end
    Store.add(cid, 'pumpkin' .. i)
    local n = 1
    for k in pairs(seen) do if k:match('^pumpkin%d+$') then n = n + 1 end end
    if n >= #H.pumpkins then
        Bridge:AddMoney(src, 'bank', H.reward)
        if GetResourceState('gs_social') == 'started' then
            pcall(function() exports.gs_social:Newsroom('flash', ('%s a trouvé les %d citrouilles d\'Halloween !'):format(Bridge:GetName(src) or '?', #H.pumpkins)) end)
        end
        return true, ('Les %d citrouilles ! Récompense : %d $'):format(#H.pumpkins, H.reward)
    end
    return true, ('Citrouille %d / %d'):format(n, #H.pumpkins)
end

lib.callback.register('gs_roadside:pumpkin', function(src, i)
    if not Security:RateLimit(src, 'gs_roadside:pumpkin', 3, 5000) then return false, 'Doucement.' end
    return Halloween.pumpkin(src, i)
end)

lib.addCommand('halloween', { help = 'Halloween sur la route : on / off / auto (staff)', restricted = 'group.admin',
    params = { { name = 'mode', type = 'string', help = 'on, off ou auto' } } }, function(src, args)
    if args.mode == 'on' then Halloween.forced = true elseif args.mode == 'off' then Halloween.forced = false else Halloween.forced = nil end
    Halloween.refresh()
    Security:LogStaff(('/halloween %s par %s'):format(args.mode, src == 0 and 'console' or GetPlayerName(src)))
end)

CreateThread(function()
    while true do Halloween.refresh() Wait(600000) end
end)
