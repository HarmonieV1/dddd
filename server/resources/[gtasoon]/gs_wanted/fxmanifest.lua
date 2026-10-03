fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_wanted'
description 'Recherche intelligente : témoins, heure et météo décident si un crime est signalé, et avec quelle précision'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua', 'client/search.lua' }
