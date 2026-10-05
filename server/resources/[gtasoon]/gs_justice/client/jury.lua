-- gs_justice (client) · V11.2 « Les jurés de Los Santos » : convocation reçue où que tu sois, vote en un clic, /jury pour la rouvrir.
local pending -- { id, charge, defendant, pieces, seconds, fee, until }

local function open()
    if not pending or GetGameTimer() > pending.untilAt then pending = nil return lib.notify({ description = 'Aucune convocation en cours.', type = 'inform' }) end
    local left = math.max(0, math.floor((pending.untilAt - GetGameTimer()) / 1000))
    local function vote(guilty)
        local ok, msg = lib.callback.await('gs_justice:juryVote', false, pending.id, guilty)
        lib.notify({ description = msg, type = ok and 'success' or 'error' })
        if ok then pending = nil end
    end
    lib.registerContext({ id = 'gs_justice_jury', title = ('Juré · affaire #%d'):format(pending.id), options = {
        { title = pending.defendant, description = ('Accusé de : %s'):format(pending.charge), icon = 'user', readOnly = true },
        { title = ('%d pièce(s) retenue(s) par le juge'):format(pending.pieces), icon = 'folder-open', readOnly = true },
        { title = ('Il te reste %d s · indemnité %d $'):format(left, pending.fee), icon = 'clock', readOnly = true },
        { title = 'Coupable', icon = 'gavel', iconColor = '#ff5470', onSelect = function() vote(true) end },
        { title = 'Non coupable', icon = 'scale-balanced', iconColor = '#5aff8c', onSelect = function() vote(false) end },
    } })
    lib.showContext('gs_justice_jury')
end

RegisterNetEvent('gs_justice:client:jury', function(d)
    pending = d
    pending.untilAt = GetGameTimer() + (d.seconds or 180) * 1000
    lib.notify({ title = 'Convocation du tribunal', description = ('Tu es tiré au sort comme juré (affaire #%d). /%s pour voter.'):format(d.id, Config.Jury.command),
        type = 'warning', duration = 12000, icon = 'scale-balanced' })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    open()
end)

RegisterCommand(Config.Jury.command, open, false)
