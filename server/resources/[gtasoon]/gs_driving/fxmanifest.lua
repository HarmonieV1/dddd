fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_driving'
description 'Permis de conduire : accordé à tout le monde à la connexion (carte remise une fois), retiré ou rendu par la police. Auto-école (code + conduite) gardée en option (Config.FreeLicence = false).'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
