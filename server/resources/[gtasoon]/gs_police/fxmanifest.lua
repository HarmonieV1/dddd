fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_police'
description 'Interventions police / EMS (F4) : menottes, escorte, véhicule, fouille, prison RP, casier, fourrière, cônes / herse, radar ; réanimer, soigner'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/dossiers.lua', 'server/prison.lua', 'server/custody.lua' }
client_scripts { 'client/main.lua', 'client/tools.lua', 'client/dossiers.lua', 'client/prison.lua', 'client/custody.lua' }
