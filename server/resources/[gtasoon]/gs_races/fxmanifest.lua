fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_races'
description 'Courses de rue classées : chrono solo et courses à mise (cagnotte), classement par circuit affiché dans Vibe. Chronos et paiements côté serveur.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
