-- Pack de véhicules « addon » GTA SOON (modèles ajoutés au jeu, streamés aux joueurs).
-- Mode d'emploi complet : docs/VEHICULES_ADDON.md. Ne rien mettre ici sans licence / autorisation de l'auteur.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_cars'
description 'Véhicules addon GTA SOON (stream/ = .yft/.ytd, data/<modele>/ = .meta)'
version '0.1.0'

files {
    'data/**/vehicles.meta',
    'data/**/carvariations.meta',
    'data/**/carcols.meta',
    'data/**/handling.meta',
    'data/**/vehiclelayouts.meta',
}

data_file 'HANDLING_FILE'            'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE'    'data/**/vehicles.meta'
data_file 'CARCOLS_FILE'             'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE'   'data/**/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE'     'data/**/vehiclelayouts.meta'
