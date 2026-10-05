# Génère les images d'objets manquantes (style emoji plat, 100x100, comme overrides/ox_inventory/web/images) :
#  - server/overrides/ox_inventory/web/images : nos objets (toujours posés) ;
#  - server/item-icons : objets de base ox_inventory / Qbox, posés SEULEMENT si l'objet n'a pas déjà d'image
#    (METTRE-A-JOUR.bat), + default.png pour tout objet restant sans image.
from PIL import Image, ImageDraw, ImageFont
import os
FONT = ImageFont.truetype('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf', 109)

def icon(emoji, path):
    im = Image.new('RGBA', (136, 136), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((68, 68), emoji, font=FONT, embedded_color=True, anchor='mm')
    bbox = im.getbbox()
    if bbox: im = im.crop(bbox)
    w, h = im.size
    s = 84 / max(w, h)
    im = im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)
    out = Image.new('RGBA', (100, 100), (0, 0, 0, 0))
    out.paste(im, ((100 - im.size[0]) // 2, (100 - im.size[1]) // 2), im)
    out.save(path, optimize=True)

OURS = {  # nos objets sans image propre
    'advancedkit': '🧰', 'scrapmetal': '🔩', 'weed': '🌿', 'paperbag': '🛍️', 'trash_chips': '🍟', 'donut': '🍩',
    'cigarettes_redwood': '🚬', 'spraycan': '🎨', 'huntingknife': '🔪', 'burger': '🍔', 'fries': '🍟',
}
BASE = {
    'black_money': '💵', 'money': '💶', 'sprunk': '🥤', 'water': '💧', 'mustard': '🌭', 'bandage': '🩹', 'parachute': '🪂',
    'garbage': '🗑️', 'identification': '🪪', 'panties': '🩲', 'lockpick': '🗝️', 'phone': '📱', 'radio': '📻', 'armour': '🦺',
    'clothing': '👕', 'mastercard': '💳', 'id_card': '🪪', 'driver_license': '🪪', 'weaponlicense': '📜', 'lawyerpass': '💼',
    'visa': '💳', 'markedbills': '💵', 'cryptostick': '💾', 'sandwich': '🥪', 'tosti': '🥪', 'twerks_candy': '🍫',
    'snikkel_candy': '🍬', 'kurkakola': '🥤', 'coffee': '☕', 'beer': '🍺', 'whiskey': '🥃', 'vodka': '🍸', 'grape': '🍇',
    'wine': '🍷', 'grapejuice': '🧃', 'joint': '🚬', 'cokebaggy': '🧂', 'crack_baggy': '🧂', 'xtcbaggy': '💊', 'weed_brick': '🧱',
    'coke_brick': '🧱', 'coke_small_brick': '📦', 'oxy': '💊', 'meth': '🧪', 'rolling_paper': '📄', 'weed_whitewidow': '🌿',
    'weed_skunk': '🌿', 'weed_purplehaze': '🌿', 'weed_ogkush': '🌿', 'weed_amnesia': '🌿', 'weed_ak47': '🌿',
    'weed_whitewidow_seed': '🌱', 'weed_skunk_seed': '🌱', 'weed_purplehaze_seed': '🌱', 'weed_ogkush_seed': '🌱',
    'weed_amnesia_seed': '🌱', 'weed_ak47_seed': '🌱', 'empty_weed_bag': '👝', 'weed_nutrition': '🧴', 'repairkit': '🧰',
    'advancedrepairkit': '🧰', 'cleaningkit': '🧽', 'tunerlaptop': '💻', 'nitrous': '🧯', 'harness': '🎽', 'handcuffs': '⛓️',
    'police_stormram': '🔨', 'empty_evidence_bag': '👝', 'filled_evidence_bag': '🧾', 'heavyarmor': '🦺', 'ifaks': '🩺',
    'firstaid': '⛑️', 'painkillers': '💊', 'walkstick': '🦯', 'jerry_can': '⛽', 'screwdriverset': '🪛', 'drill': '🔧',
    'electronickit': '🔌', 'gatecrack': '📟', 'thermite': '🧨', 'trojan_usb': '💾', 'security_card_01': '💳',
    'security_card_02': '💳', 'laptop': '💻', 'tablet': '📱', 'fitbit': '⌚', 'diving_gear': '🤿', 'binoculars': '🔭',
    'lighter': '🔥', 'diamond_ring': '💍', 'goldchain': '📿', '10kgoldchain': '📿', 'rolex': '⌚', 'goldbar': '🪙',
    'metalscrap': '🔩', 'plastic': '🧴', 'copper': '🟤', 'iron': '⚙️', 'aluminum': '🥫', 'steel': '⚙️', 'glass': '🪟',
    'rubber': '🛞', 'casinochips': '🎰', 'stickynote': '🗒️', 'moneybag': '💰', 'printerdocument': '📄', 'labkey': '🔑',
    'certificate': '📜', 'radioscanner': '📡', 'pinger': '📍', 'advancedlockpick': '🗝️', 'cigarettes': '🚬',
    'weapon_parts': '🔩', 'diamond': '💎', 'emerald': '💚', 'ruby': '❤️', 'sapphire': '💙', 'fishingrod': '🎣', 'bait': '🪱',
    'fishbait': '🪱', 'testburger': '🍔', 'scrapmetal': '🔩', 'burger': '🍔', 'paperbag': '🛍️',
    'at_suppressor_light': '🔇', 'at_clip_extended_pistol': '🔫', 'at_flashlight': '🔦', 'at_scope_macro': '🔭', 'at_grip': '✊',
    'ammo-9': '🔫', 'ammo-45': '🔫', 'ammo-rifle': '🔫', 'ammo-rifle2': '🔫', 'ammo-shotgun': '🔫', 'ammo-22': '🔫',
    'ammo-38': '🔫', 'ammo-44': '🔫', 'ammo-50': '🔫', 'ammo-sniper': '🔫', 'ammo-flare': '🎆',
    'default': '📦',
}
if __name__ == '__main__':
    o = 'server/overrides/ox_inventory/web/images'
    for n, e in OURS.items(): icon(e, f'{o}/{n}.png')
    for n, e in BASE.items(): icon(e, f'server/item-icons/{n}.png')
    print(f'{len(OURS)} images de nos objets, {len(BASE)} images de secours générées')
