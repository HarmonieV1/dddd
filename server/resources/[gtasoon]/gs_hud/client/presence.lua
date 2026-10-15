-- gs_hud (client) · V12.59 « Joue à RoadLine RP » sur Discord (backtest 15/10 : le profil Discord des joueurs affichait
-- « Joue à Qbox »). Ce nom vient de l'APPLICATION Discord dont l'identifiant est donné au jeu : qbx_core utilisait celle de
-- Qbox. Sa présence est coupée (retouche de METTRE-A-JOUR) et remplacée par la nôtre, si `gs_discord_appid` est réglé :
--   1. discord.com/developers → New Application → nom « RoadLine RP » (c'est CE nom qui s'affiche) ;
--   2. Rich Presence → Art Assets : image nommée « logo » ;
--   3. server.cfg : setr gs_discord_appid "<Application ID>"  (et setr gs_discord_invite "https://discord.gg/…").
-- Sans identifiant : rien n'est envoyé, Discord affiche « Joue à FiveM » (plus jamais « Qbox »).
local appId = GetConvar('gs_discord_appid', '')
if not appId:match('^%d+$') then return end

SetDiscordAppId(appId)
SetDiscordRichPresenceAsset('logo')
SetDiscordRichPresenceAssetText('RoadLine RP · La ville se souvient')
local invite = GetConvar('gs_discord_invite', '')
if invite:match('^https://discord%.gg/') or invite:match('^https://discord%.com/invite/') then
    SetDiscordRichPresenceAction(0, 'Rejoindre le Discord', invite)
end
local site = GetConvar('gs_site_url', '')
if site:match('^https://') then SetDiscordRichPresenceAction(1, 'Site RoadLine', site) end

CreateThread(function()
    while true do
        local n = #GetActivePlayers()
        local c = GetEntityCoords(cache.ped)
        local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
        SetRichPresence(('En ville à Los Santos%s · %d citoyen%s autour'):format(street ~= '' and (' · ' .. street) or '', n, n > 1 and 's' or ''))
        Wait(30000)
    end
end)
