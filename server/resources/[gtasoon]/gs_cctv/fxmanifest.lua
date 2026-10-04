fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_cctv'
description 'V10.1 · Caméras de surveillance : les caméras de la ville relèvent les véhicules qui passent (plaque visible, modèle, couleur, vitesse). La police consulte les passages au commissariat ; les gangs apprennent à les éviter… ou à les aveugler à la bombe de peinture.'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
