-- Items utilisés par les ressources GTA SOON. INSTALLER.bat / METTRE-A-JOUR.bat les ajoutent tout seuls
-- dans ox_inventory/data/items.lua (une ligne = un item) :
--   - un item absent est ajouté ;
--   - un item déjà présent n'est PAS touché, sauf si la ligne finit par « -- remplace » : l'ancienne définition
--     est alors retirée et remplacée (ex : bière / vin / café de Qbox, déclarés sans aucun effet).
-- Images : client.image pointe vers une image déjà fournie par Qbox (ox_inventory/web/images).
-- Au démarrage, gs_economy / gs_jobs / gs_drugs affichent en jaune dans la console les items encore manquants.

['sandwich'] = { label = 'Sandwich', weight = 200, stack = true, close = true, client = { status = { hunger = 150000 }, anim = 'eating', usetime = 2500, notification = 'Pas mal, ce sandwich.' } }, -- remplace
['repairkit'] = { label = 'Kit de réparation', weight = 2500, stack = true, close = true, description = 'Réparation de fortune du moteur (le mécano fait le reste).', client = { export = 'gs_details.repair' } }, -- remplace
['advancedrepairkit'] = { label = 'Kit de réparation avancé', weight = 4000, stack = true, close = true, description = 'Réparation complète du véhicule.', client = { image = 'advancedkit.png', export = 'gs_details.advancedRepair' } }, -- remplace
['cleaningkit'] = { label = 'Kit de nettoyage', weight = 250, stack = true, close = true, client = { export = 'gs_details.clean' } }, -- remplace
['scrapmetal'] = { label = 'Ferraille', weight = 500, stack = true },
['copper'] = { label = 'Cuivre', weight = 500, stack = true },
['weed_leaf'] = { label = 'Feuille de cannabis', weight = 50, stack = true, client = { image = 'weed.png' } }, -- remplace
['weed_bag'] = { label = 'Sachet de cannabis', weight = 20, stack = true, client = { image = 'weed_baggy.png' } }, -- remplace
['coca_leaf'] = { label = 'Feuille de coca', weight = 50, stack = true, client = { image = 'cocaineleaf.png' } }, -- remplace
['coke_bag'] = { label = 'Pochon de cocaïne', weight = 20, stack = true, client = { image = 'cocaine_baggy.png' } }, -- remplace
['gs_parcel'] = { label = 'Colis', weight = 800, stack = true, description = 'Objet de quête', client = { image = 'paperbag.png' } }, -- remplace
['gs_envelope'] = { label = 'Enveloppe', weight = 20, stack = true, description = 'Objet de quête', client = { image = 'printerdocument.png' } }, -- remplace
['gs_chips'] = { label = 'Chips', weight = 100, stack = true, close = true, client = { image = 'trash_chips.png', status = { hunger = 60000 }, anim = 'eating', usetime = 2000 } }, -- remplace
['gs_donut'] = { label = 'Donut', weight = 100, stack = true, close = true, client = { image = 'donut.png', status = { hunger = 80000 }, anim = 'eating', usetime = 2000 } }, -- remplace
['gs_energy'] = { label = 'Boisson énergisante', weight = 300, stack = true, close = true, client = { image = 'cola.png', status = { thirst = 150000 }, anim = 'drinking', usetime = 2000 } }, -- remplace
['coffee'] = { label = 'Café', weight = 200, stack = true, close = true, client = { status = { thirst = 80000 }, anim = 'drinking', usetime = 2500, notification = 'Réveillé !' } }, -- remplace
['beer'] = { label = 'Bière', weight = 350, stack = true, close = true, client = { status = { thirst = 100000 }, anim = 'drinking', usetime = 3000, export = 'gs_economy.drink' } }, -- remplace
['wine'] = { label = 'Bouteille de vin', weight = 750, stack = true, close = true, client = { status = { thirst = 80000 }, anim = 'drinking', usetime = 3500, export = 'gs_economy.drink' } }, -- remplace
['vodka'] = { label = 'Vodka', weight = 700, stack = true, close = true, client = { status = { thirst = 50000 }, anim = 'drinking', usetime = 3500, export = 'gs_economy.drink' } }, -- remplace
['whiskey'] = { label = 'Whisky', weight = 700, stack = true, close = true, client = { status = { thirst = 50000 }, anim = 'drinking', usetime = 3500, export = 'gs_economy.drink' } }, -- remplace
['gs_cigarettes'] = { label = 'Paquet de cigarettes', weight = 50, stack = false, close = true, consume = 0.1, description = '10 cigarettes. Il faut un briquet.', client = { image = 'cigarettes_redwood.png', usetime = 1500, export = 'gs_economy.smoke' } }, -- remplace
['spraycan'] = { label = 'Bombe de peinture', weight = 300, stack = true, close = true, consume = 0.25, description = 'Pour taguer au nom de ton gang (4 tags par bombe).', client = { image = 'WEAPON_HAZARDCAN.png', export = 'gs_gangs.spray' } }, -- remplace
