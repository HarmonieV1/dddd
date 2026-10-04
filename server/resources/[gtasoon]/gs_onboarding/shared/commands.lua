-- Commandes visibles par les joueurs (suggestions du chat). Tout le reste est masqué pour eux : touches (F1, F3…),
-- outils staff, commandes internes. Le staff (helper et plus) voit tout. Masquer ≠ autoriser : chaque commande sensible
-- reste vérifiée par le serveur (niveau staff / ACE).
PlayerCommands = {
    report = true, me = true, ['do'] = true, touches = true, regles = true,
    quartiers = true, reputation = true, saison = true, retoucheperso = true, hud = true, factures = true,
    boutique = true, radio = true, e = true, emote = true, emotes = true, walk = true, walks = true, cancelemote = true,
    tribunal = true, taxi = true, depanneur = true, em = true, emotemenu = true,
    permis = true, rencontres = true, mentor = true, rumeurs = true, carnet = true, histoire = true, droits = true, cinema = true, ralenti = true, -- V8
}
