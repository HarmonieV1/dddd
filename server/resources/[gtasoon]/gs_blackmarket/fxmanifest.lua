fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_blackmarket'
description 'Marché noir (armes non déclarées, munitions, accessoires) : contact qui change de planque, stock limité et prix selon la rareté, accès gang ou réputation de rue. Armureries légales plafonnées (munitions par jour).'
version '0.1.0'

dependencies { 'ox_lib', 'ox_inventory', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua', 'server/legal.lua' }
client_scripts { 'client/main.lua' }
