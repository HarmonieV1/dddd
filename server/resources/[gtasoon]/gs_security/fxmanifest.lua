fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_security'
description 'Sécurité serveur : rate-limit + anti-flood, distances, nettoyage de texte, logs Discord, blocage des events natifs de triche, pots de miel (V12.4)'
version '0.3.0'

shared_scripts { '@ox_lib/init.lua' }
server_scripts { 'server/main.lua', 'server/anticheat.lua', 'server/watch.lua', 'server/honeypot.lua' }
