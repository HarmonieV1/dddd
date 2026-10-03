fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_business'
description 'Commerces tenus par des joueurs (bar, restaurant) : préparation à partir du stock (réserve du job), caisse (prix fixés par le patron), vente en libre-service majorée sans employé, comptabilité.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
