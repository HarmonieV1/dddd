fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_drugs'
description 'Drogue : récolte → transformation → vente aux PNJ ; prix selon saturation, météo, heure, territoires ; signalements'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_wanted', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
