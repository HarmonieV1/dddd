# Faire venir 1 ou 2 amis sur le serveur hébergé chez toi

Oui, c'est possible depuis ton PC. Trois façons, de la plus simple à la plus « propre ».

## A. Réseau privé virtuel (le plus simple, sans toucher la box)
1. Toi et tes amis installez **Tailscale** (ou ZeroTier / Radmin VPN), gratuit, et rejoignez le même réseau.
2. Tu lances le serveur comme d'habitude.
3. Tes amis ouvrent FiveM → F8 → `connect 100.x.y.z:30120` (l'adresse Tailscale de ton PC).
Aucune redirection de port, rien d'exposé sur Internet. Idéal pour tester à 2-3.

## B. Redirection de port sur ta box
1. Donne une IP fixe locale à ton PC (réglages de la box, « bail DHCP statique »).
2. Redirige le port **30120 en TCP et UDP** vers cette IP.
3. Pare-feu Windows : autorise FXServer (ou le port 30120 TCP/UDP) en entrée.
4. Tes amis : F8 → `connect TON_IP_PUBLIQUE:30120` (ton IP publique : recherche « quelle est mon IP »).
⚠️ Ton IP est visible par ceux qui se connectent : ne la partage qu'avec des proches. Pour du public, passe par un hébergeur
avec anti-DDoS (voir docs/SECURITY.md).

## C. Lien cfx.re (liste des serveurs)
Avec une clé de licence valide et le port ouvert (B), le serveur apparaît dans la liste FiveM et a un lien `cfx.re/join/xxxx`.
Pour des tests entre amis, garde plutôt `sv_master1 ""` (serveur non listé) dans un fichier cfg privé.

## Avant d'inviter
- `DEVENIR-ADMIN.bat` pour toi ; tes amis n'ont rien à installer à part FiveM.
- Liste blanche : laisse `gs_whitelist "false"` pour les tests, ou ajoute-les avec `/whitelist add <id>`.
- Si ton PC se met en veille, le serveur se fige (« Loop svMain seems hung ») : désactive la veille pendant les sessions.
