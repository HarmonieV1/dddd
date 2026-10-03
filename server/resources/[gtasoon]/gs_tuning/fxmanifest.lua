fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_tuning'
description 'Salon de personnalisation : néons, plaque personnalisée, et personnalisation complète par le mécano en service. Propriété, unicité et paiement vérifiés côté serveur.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers', 'gs_jobs' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/mechanic.lua' }
client_scripts { 'client/main.lua', 'client/mechanic.lua' }
