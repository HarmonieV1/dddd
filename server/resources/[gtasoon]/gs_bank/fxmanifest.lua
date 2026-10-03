fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_bank'
description 'Banque : distributeurs (ox_target sur les props du jeu) et guichets Fleeca / Pacific. Retrait / dépôt, plafond par jour, historique. Tout côté serveur.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
