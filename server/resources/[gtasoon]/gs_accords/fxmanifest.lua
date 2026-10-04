fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_accords'
description 'V9 · Contrats signés appliqués par le serveur : prêt avec échéances, salaire privé (garde du corps, chauffeur…), location (le mariage reste à la mairie, gs_civil). Signature face à face, prélèvements automatiques, retards, litiges transmis au tribunal.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
