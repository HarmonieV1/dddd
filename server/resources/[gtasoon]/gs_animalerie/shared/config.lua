-- [CONFIG] gs_animalerie · V12.63 « Animalerie » (backtest du 16/10 : « il nous faudrait un job avec des animations en rapport,
-- là ça fait vide »). Emploi public `animalerie` (gs_jobs : Pôle Emploi, prise de service n'importe où), travail dans la boutique
-- de la map Patoche : animaux exposés (visibles de tous), réassort, gamelles, cages, toilettage, clients au comptoir.
--
-- POSTES : à placer en jeu, dans la boutique : F11 → Monde et lieux → Déplacer un point → « Animalerie · … » (le comptoir d'abord).
-- Tant qu'un poste n'est pas placé, il se range tout seul autour de la position de la map de l'animalerie (lue par gs_admin) ;
-- si la map n'est pas trouvée (pack chiffré illisible), rien n'apparaît tant que le comptoir n'est pas placé.
Config = {}

Config.Job = 'animalerie'
Config.Map = 'petshop'                          -- mot cherché dans le nom des maps installées (gsa_patoche_petshop_pack)
Config.Unplaced = vec3(-8500.0, -8500.0, 0.0)   -- marque « pas encore placé » (ne pas changer)
Config.Range = 3.0                              -- distance d'action à un poste
Config.ShowDistance = 45.0                      -- animaux (et client) créés à moins de X m du comptoir

-- `offset` : place provisoire autour de la map tant que le poste n'est pas placé (petits décalages, en mètres)
Config.Posts = {
    counter  = { label = 'Animalerie · Comptoir',   coords = vec4(-8500.0, -8500.0, 0.0, 0.0), offset = vec3(0.0, 0.0, 0.0) },
    stock    = { label = 'Animalerie · Réserve',    coords = vec4(-8500.0, -8500.0, 0.0, 0.0), offset = vec3(-3.5, -2.5, 0.0) },
    bowls    = { label = 'Animalerie · Gamelles',   coords = vec4(-8500.0, -8500.0, 0.0, 0.0), offset = vec3(3.0, 2.5, 0.0) },
    cages    = { label = 'Animalerie · Cages',      coords = vec4(-8500.0, -8500.0, 0.0, 0.0), offset = vec3(-3.0, 2.5, 0.0) },
    grooming = { label = 'Animalerie · Toilettage', coords = vec4(-8500.0, -8500.0, 0.0, 0.0), offset = vec3(3.5, -2.5, 0.0) },
}

-- Tâches (payées par la ville, sur le compte en banque) : poste, durée, attente avant de refaire la même, paie
Config.Tasks = {
    stock    = { post = 'stock', label = 'Prendre un carton de croquettes', icon = 'box', ms = 4000, cooldown = 15,
                 scenario = 'PROP_HUMAN_BUM_BIN' },
    bowls    = { post = 'bowls', label = 'Remplir les gamelles', icon = 'bowl-food', ms = 8000, cooldown = 90, pay = { 60, 90 },
                 needs = 'stock', scenario = 'CODE_HUMAN_MEDIC_KNEEL' },
    cages    = { post = 'cages', label = 'Nettoyer les cages', icon = 'broom', ms = 10000, cooldown = 120, pay = { 55, 85 },
                 scenario = 'WORLD_HUMAN_MAID_CLEAN' },
    grooming = { post = 'grooming', label = 'Toiletter le chien', icon = 'scissors', ms = 12000, cooldown = 150, pay = { 90, 130 },
                 anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 } },
    serve    = { post = 'counter', label = 'Servir le client', icon = 'cash-register', ms = 6000, pay = { 70, 110 }, tip = { 0, 40 },
                 anim = { dict = 'mp_common', clip = 'givetake1_a', flag = 48 } },
}
-- Carton porté de la réserve aux gamelles (mêmes réglages que le colis du livreur, gs_jobs)
Config.Carry = { seconds = 120, model = 'hei_prop_heist_box', bone = 60309, pos = vec3(0.025, 0.08, 0.255), rot = vec3(-145.0, 290.0, 0.0),
    anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 } }

-- Clients au comptoir (pour l'employé en service) : un toutes les `every` s, il attend `wait` s
Config.Customers = { every = { 150, 300 }, wait = 120,
    models = { 'a_f_y_hipster_02', 'a_m_y_hipster_01', 'a_f_m_bevhills_01', 'a_m_m_bevhills_02', 'a_f_y_tourist_01' } }

-- Animaux exposés (modèles du jeu de base), autour d'un poste ; décalage dans le repère du poste (x à droite, y devant)
Config.Animals = {
    { model = 'a_c_cat_01',    post = 'cages',    offset = vec3(-0.8, 0.6, 0.0), heading = 180.0, scenario = 'WORLD_CAT_SLEEPING_GROUND' },
    { model = 'a_c_rabbit_01', post = 'cages',    offset = vec3(0.7, 0.5, 0.0),  heading = 160.0, scenario = 'WORLD_RABBIT_EATING' },
    { model = 'a_c_westy',     post = 'cages',    offset = vec3(0.0, 1.2, 0.0),  heading = 200.0, scenario = 'WORLD_DOG_SITTING_SMALL' },
    { model = 'a_c_pug',       post = 'bowls',    offset = vec3(0.6, 0.8, 0.0),  heading = 220.0, scenario = 'WORLD_DOG_SITTING_SMALL' },
    { model = 'a_c_retriever', post = 'bowls',    offset = vec3(-0.8, 0.9, 0.0), heading = 140.0, scenario = 'WORLD_DOG_SITTING_RETRIEVER' },
    { model = 'a_c_poodle',    post = 'grooming', offset = vec3(0.0, 0.9, 0.0),  heading = 180.0, scenario = 'WORLD_DOG_SITTING_SMALL' },
    { model = 'a_c_hen',       post = 'stock',    offset = vec3(1.0, 0.8, 0.0),  heading = 90.0,  scenario = 'WORLD_HEN_PECKING' },
}

--- Position d'un poste : placée par le staff, sinon rangée autour de la map (`anchor` = GlobalState.gsPetshopAnchor), sinon nil
function Config.PostAt(key, anchor)
    local p = Config.Posts[key]
    if not p then return nil end
    local c = p.coords
    if #(vec3(c.x, c.y, c.z) - Config.Unplaced) > 1.0 then return vec4(c.x, c.y, c.z, c.w or 0.0) end
    if type(anchor) ~= 'table' or not tonumber(anchor.x) then return nil end
    local o = p.offset or vec3(0.0, 0.0, 0.0)
    return vec4(anchor.x + o.x, anchor.y + o.y, anchor.z + o.z, 0.0)
end

--- Point à `off` (x à droite, y devant) dans le repère d'un poste orienté `at.w`
function Config.Around(at, off)
    local h = math.rad(at.w or 0.0)
    local c, s = math.cos(h), math.sin(h)
    return vec3(at.x + off.x * c - off.y * s, at.y + off.x * s + off.y * c, at.z + (off.z or 0.0))
end
