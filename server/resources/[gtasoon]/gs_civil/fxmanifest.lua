fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_civil'
description 'État civil à la mairie : mariage (demande + accord, officié par un agent de la mairie s\'il y en a un en service), divorce, conjoint visible au contrôle d\'identité.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
