fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_interiors'
description 'Portes vers les intérieurs cachés du jeu (bob74_ipl) : labos de gangs, club-house du Lost MC. Accès vérifié par le serveur.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
