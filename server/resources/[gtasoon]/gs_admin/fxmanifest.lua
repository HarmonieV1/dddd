fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_admin'
description 'Panel staff RP (F10) + menu staff rapide (F11) : tickets, fiche joueur branchée sur nos systèmes, sanctions publiques, jail, notes, économie/météo/jobs'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua', 'client/quick.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/index.html', 'web/dist/assets/*' }
