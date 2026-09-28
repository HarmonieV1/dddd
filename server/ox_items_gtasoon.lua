-- Items utilisés par les ressources GTA SOON, à COLLER dans ox_inventory/data/items.lua
-- (à l'intérieur du grand tableau `return { ... }`, par exemple juste avant la dernière accolade).
-- Ne copie que ceux qui n'existent pas déjà : ox_inventory fournit normalement water, burger, sprunk,
-- bandage, lockpick, radio, phone, scrapmetal, black_money (vérifie avec Ctrl+F dans items.lua).
-- Au démarrage, gs_economy / gs_jobs / gs_drugs affichent en jaune dans la console les items encore manquants.

['sandwich'] = { label = 'Sandwich', weight = 200, stack = true, close = true },
['repairkit'] = { label = 'Kit de réparation', weight = 2500, stack = true, close = true },
['copper'] = { label = 'Cuivre', weight = 500, stack = true },
['weed_leaf'] = { label = 'Feuille de cannabis', weight = 50, stack = true },
['weed_bag'] = { label = 'Sachet de cannabis', weight = 20, stack = true },
