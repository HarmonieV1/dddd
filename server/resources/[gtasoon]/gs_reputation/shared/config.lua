-- [CONFIG] Réputation. Trois jauges de 0 à 1000. Gains par activité (gs_quests) et par like reçu sur Vibe.
Config = {}

Config.Max = 1000
Config.Tiers = { { at = 0, label = 'Inconnu' }, { at = 100, label = 'Connu' }, { at = 300, label = 'Respecté' }, { at = 600, label = 'Réputé' }, { at = 900, label = 'Légende' } }

-- activité (gs_quests Reward / Track) → { jauge, points }
Config.Gains = {
    job_mission = { 'legal', 5 }, shop_buy = { 'legal', 1 }, rental = { 'legal', 1 }, harvest = { 'legal', 2 }, sell = { 'legal', 1 },
    drug_sale = { 'street', 3 }, heist = { 'street', 10 }, race = { 'street', 5 },
    quest = { 'legal', 10 },
}
Config.LikePoints = 1              -- réputation média par like reçu (retiré si le like est enlevé)

-- Effets
Config.LegalDiscount = { [300] = 0.03, [600] = 0.06, [900] = 0.10 }   -- remise dans les commerces (gs_economy)
Config.StreetBonus = { [300] = 0.05, [600] = 0.10, [900] = 0.15 }      -- bonus de prix de la drogue (gs_drugs)
Config.GreetAt = 300               -- les vendeurs te saluent par ton prénom (légale ou média)
Config.FlushSeconds = 60
