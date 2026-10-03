fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_rental'
description 'Location de vélos, scooters et petites citadines près des spawns : pas cher, temporaire, marqueurs au sol'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
