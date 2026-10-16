fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_animalerie'
description 'V12.63 · Métier d\'animalerie (map Patoche) : animaux exposés dans la boutique, réassort, gamelles, cages, toilettage, clients ; payé à la tâche par la ville.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers', 'gs_jobs' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
