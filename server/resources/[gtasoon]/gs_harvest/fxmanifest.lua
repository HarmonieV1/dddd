fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_harvest'
description 'Métiers de récolte libres : pêche, mine, bûcheron, fermier, chasse. Outil requis, durée réelle vérifiée, revente aux acheteurs.'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
