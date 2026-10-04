-- gs_security : protections réseau de base contre les menus de triche (events natifs du jeu relayés par le serveur).
-- Aucun script GTA SOON n'utilise ces events : on les bloque et on journalise l'auteur.
local function name(src) return ('%s [%s]'):format(GetPlayerName(src) or '?', src) end

-- Donner / retirer des armes à un AUTRE joueur, ou vider ses tâches (l'éjecter de son véhicule, le figer) :
-- uniquement possible via un menu de triche.
for _, ev in ipairs({ 'giveWeaponEvent', 'removeWeaponEvent', 'removeAllWeaponsEvent' }) do
    AddEventHandler(ev, function(sender)
        CancelEvent()
        GSSec.LogStaff(('[Anti-triche] %s : %s bloqué'):format(name(sender), ev))
    end)
end

AddEventHandler('clearPedTasksEvent', function(sender, data)
    if data and data.immediately then
        CancelEvent()
        GSSec.LogStaff(('[Anti-triche] %s : éjection forcée d\'un joueur bloquée'):format(name(sender)))
    end
end)

-- Explosions : une rafale (menus « tout faire exploser ») est bloquée ; un accident isolé passe.
AddEventHandler('explosionEvent', function(sender, ev)
    sender = tonumber(sender) -- FiveM le transmet en chaîne
    if not GSSec.RateLimit(sender, 'native:explosion', 4, 10000) then
        CancelEvent()
        return
    end
    if ev and ev.isInvisible then -- explosion invisible = arme de triche
        CancelEvent()
        GSSec.LogStaff(('[Anti-triche] %s : explosion invisible bloquée (type %s)'):format(name(sender), tostring(ev.explosionType)))
    end
end)

-- Effets de particules spammés (lag volontaire des autres joueurs)
AddEventHandler('ptFxEvent', function(sender)
    sender = tonumber(sender)
    if not GSSec.RateLimit(sender, 'native:ptfx', 30, 10000) then CancelEvent() end
end)
