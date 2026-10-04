fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_wanted'
description 'Recherche intelligente et « La ville se souvient » : témoins, heure, météo, description du suspect, mémoire des tenues et véhicules'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/memory.lua', 'server/main.lua' }
client_scripts { 'client/main.lua', 'client/search.lua' }
