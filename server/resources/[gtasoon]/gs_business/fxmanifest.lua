fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_business'
description 'Bars tenus par des joueurs (Tequi-la-la, Vanilla Unicorn, Bahama Mamas) : préparation à partir du stock (réserve du job), caisse (prix fixés par le patron), barman PNJ en libre-service sans employé, comptabilité.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/double.lua' }
client_scripts { 'client/main.lua', 'client/double.lua' }
