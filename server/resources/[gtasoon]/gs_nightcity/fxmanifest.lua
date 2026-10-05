fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_nightcity'
description 'V10.2 · Ville de jour / ville de nuit : en plus de tout ce qui existe (rien ne ferme), la nuit des groupes de PNJ sortent devant les clubs et sur les plages, et des marchés de nuit ouvrent (stands avec vendeur) ; le jour, musiciens et pêcheurs. PNJ locaux, créés à l\'approche.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_bridge', 'gs_security', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
