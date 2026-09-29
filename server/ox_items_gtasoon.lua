-- Items utilisés par les ressources GTA SOON. INSTALLER.bat / METTRE-A-JOUR.bat les ajoutent tout seuls
-- dans ox_inventory/data/items.lua (une ligne = un item) :
--   - un item absent est ajouté ;
--   - un item déjà présent n'est PAS touché, sauf si la ligne finit par « -- remplace » : l'ancienne définition
--     est alors retirée et remplacée (ex : bière / vin / café de Qbox, déclarés sans aucun effet).
-- Au démarrage, gs_economy / gs_jobs / gs_drugs affichent en jaune dans la console les items encore manquants.

['sandwich'] = { label = 'Sandwich', weight = 200, stack = true, close = true, client = { status = { hunger = 150000 }, anim = 'eating', usetime = 2500, notification = 'Pas mal, ce sandwich.' } }, -- remplace
['repairkit'] = { label = 'Kit de réparation', weight = 2500, stack = true, close = true },
['scrapmetal'] = { label = 'Ferraille', weight = 500, stack = true },
['copper'] = { label = 'Cuivre', weight = 500, stack = true },
['weed_leaf'] = { label = 'Feuille de cannabis', weight = 50, stack = true },
['weed_bag'] = { label = 'Sachet de cannabis', weight = 20, stack = true },
['coca_leaf'] = { label = 'Feuille de coca', weight = 50, stack = true },
['coke_bag'] = { label = 'Pochon de cocaïne', weight = 20, stack = true },
['gs_parcel'] = { label = 'Colis', weight = 800, stack = true, description = 'Objet de quête' },
['gs_envelope'] = { label = 'Enveloppe', weight = 20, stack = true, description = 'Objet de quête' },
['gs_chips'] = { label = 'Chips', weight = 100, stack = true, close = true, client = { status = { hunger = 60000 }, anim = 'eating', usetime = 2000 } },
['gs_donut'] = { label = 'Donut', weight = 100, stack = true, close = true, client = { status = { hunger = 80000 }, anim = 'eating', usetime = 2000 } },
['gs_energy'] = { label = 'Boisson énergisante', weight = 300, stack = true, close = true, client = { status = { thirst = 150000 }, anim = 'drinking', usetime = 2000 } },
['coffee'] = { label = 'Café', weight = 200, stack = true, close = true, client = { status = { thirst = 80000 }, anim = 'drinking', usetime = 2500, notification = 'Réveillé !' } }, -- remplace
['beer'] = { label = 'Bière', weight = 350, stack = true, close = true, client = { status = { thirst = 100000 }, anim = 'drinking', usetime = 3000, export = 'gs_economy.drink' } }, -- remplace
['wine'] = { label = 'Bouteille de vin', weight = 750, stack = true, close = true, client = { status = { thirst = 80000 }, anim = 'drinking', usetime = 3500, export = 'gs_economy.drink' } }, -- remplace
['vodka'] = { label = 'Vodka', weight = 700, stack = true, close = true, client = { status = { thirst = 50000 }, anim = 'drinking', usetime = 3500, export = 'gs_economy.drink' } }, -- remplace
['whiskey'] = { label = 'Whisky', weight = 700, stack = true, close = true, client = { status = { thirst = 50000 }, anim = 'drinking', usetime = 3500, export = 'gs_economy.drink' } }, -- remplace
['gs_cigarettes'] = { label = 'Paquet de cigarettes', weight = 50, stack = false, close = true, consume = 0.1, description = '10 cigarettes. Il faut un briquet.', client = { usetime = 1500, export = 'gs_economy.smoke' } },
