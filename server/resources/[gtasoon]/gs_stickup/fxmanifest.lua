fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_stickup'
description 'Braquage solo de PNJ (annexe) : racket de passants, caissiers, guichetiers. La peur monte avec l\'arme pointée et la voix (plus tu cries, plus ça va vite). Toujours signalé : police joueurs, sinon police IA.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge', 'gs_wanted' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
