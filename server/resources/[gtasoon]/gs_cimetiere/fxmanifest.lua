fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_cimetiere'
description 'V12.60 · Le cimetière se remplit : une mort RP laisse une vraie tombe (épitaphe), un avis de décès (Weazel, Gazette) et on y dépose des fleurs'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
