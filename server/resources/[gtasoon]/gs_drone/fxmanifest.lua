fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_drone'
description 'V12.64 · Drone de repérage : drone de la police en service (F4 → Drone, /drone), drone modifié des gangs (marché noir, gradés seulement). Portée, batterie, vision de nuit, abattable.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
