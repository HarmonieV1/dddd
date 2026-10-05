fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_city'
description 'Los Santos réactif : la tension de chaque quartier monte avec les crimes signalés et retombe avec le temps (passants, trafic, témoins, police IA, Weazel News) ; V10 : le quartier évolue (standing, déchets à ramasser, recette des commerces).'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua', 'server/standing.lua', 'server/timelapse.lua', 'server/public.lua', 'server/recap.lua' }
client_scripts { 'client/main.lua', 'client/standing.lua' }
