"""Images des objets GTA SOON pour ox_inventory (sinon : objets sans image en jeu).
Rendu des emojis Noto Color Emoji (licence OFL, libre) en PNG 100x100, posés par METTRE-A-JOUR dans
ox_inventory/web/images via server/overrides. Relancer après ajout d'un objet : python3 tools/icons/make_icons.py"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

FONT = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'server', 'overrides', 'ox_inventory', 'web', 'images')

# fichier image : emoji, teinte optionnelle (r, g, b) appliquée à l'emoji, emoji secondaire optionnel (dans un sachet)
ICONS = {
    'sandwich.png': ('🥪',), 'repairkit.png': ('🧰',), 'cleaningkit.png': ('🧽',),
    'copper.png': ('🪨', (200, 110, 50)), 'iron.png': ('🪨', (120, 130, 150)), 'goldbar.png': ('🪨', (255, 200, 0)),
    'stone.png': ('🪨',), 'weed_baggy.png': ('BAG', None, '🌿'), 'cocaine_baggy.png': ('BAG', None, '❄️'),
    'cocaineleaf.png': ('🍃',), 'envelope.png': ('✉️',), 'energy.png': ('🥤',), 'coffee.png': ('☕',),
    'beer.png': ('🍺',), 'wine.png': ('🍷',), 'vodka.png': ('🍶',), 'whiskey.png': ('🥃',), 'cocktail.png': ('🍸',),
    'whiskycola.png': ('🍹',), 'scratch_ticket.png': ('🎟️',), 'weed_seed.png': ('🫘',), 'plant_pot.png': ('🪴',),
    'fertilizer.png': ('🧪',), 'fishingrod.png': ('🎣',), 'pickaxe.png': ('⛏️',), 'axe.png': ('🪓',),
    'fish.png': ('🐟',), 'tuna.png': ('🐠',), 'wood.png': ('🪵',), 'tomato.png': ('🍅',), 'potato.png': ('🥔',),
    'meat.png': ('🥩',), 'leather.png': ('HIDE',), 'painkillers.png': ('💊',), 'outfit.png': ('👕',),
    'cashbag.png': ('💰',), 'gs_parcel.png': ('📦',), 'meat_raw.png': ('🍖',), 'milk.png': ('🥛',),
    'apple.png': ('🍎',), 'corn.png': ('🌽',), 'wheat.png': ('🌾',), 'egg.png': ('🥚',), 'lettuce.png': ('🥬',),
    'phone_card.png': ('📇',), 'jerrycan.png': ('⛽',), 'racing_flag.png': ('🏁',),
    'evidence_bag.png': ('BAG', None, '🔎'), 'gloves.png': ('🧤',), 'bleach.png': ('🧴',), 'canteen.png': ('🎫',), 'prison_tools.png': ('🔧',), 'fakeplate.png': ('🪪',), 'camera.png': ('📷',), 'photo.png': ('🖼️',),
}

font = ImageFont.truetype(FONT, 109)


def emoji(ch, tint=None):
    im = Image.new('RGBA', (136, 128), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((0, 0), ch, font=font, embedded_color=True)
    im = im.crop(im.getbbox())
    if tint:
        grey = ImageEnhance.Color(im).enhance(0).convert('RGBA')
        col = Image.new('RGBA', im.size, tint + (255,))
        im = Image.composite(Image.blend(grey, col, 0.65), Image.new('RGBA', im.size), im.split()[3])
    return im


def bag(inner):
    im = Image.new('RGBA', (100, 100), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((18, 22, 82, 92), 10, fill=(225, 235, 240, 150), outline=(255, 255, 255, 230), width=3)
    d.rectangle((18, 22, 82, 30), fill=(220, 60, 60, 230))
    e = emoji(inner)
    e.thumbnail((44, 44))
    im.alpha_composite(e, ((100 - e.width) // 2, 36 + (52 - e.height) // 2))
    return im


def hide():
    im = Image.new('RGBA', (100, 100), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(20, 20), (38, 28), (50, 14), (62, 28), (80, 20), (76, 46), (88, 62), (70, 70), (64, 88), (50, 80), (36, 88), (30, 70), (12, 62), (24, 46)]
    d.polygon(pts, fill=(150, 95, 55, 255), outline=(95, 55, 30, 255), width=3)
    return im


os.makedirs(OUT, exist_ok=True)
for name, spec in ICONS.items():
    if spec[0] == 'BAG':
        im = bag(spec[2])
    elif spec[0] == 'HIDE':
        im = hide()
    else:
        e = emoji(spec[0], spec[1] if len(spec) > 1 else None)
        e.thumbnail((86, 86))
        im = Image.new('RGBA', (100, 100), (0, 0, 0, 0))
        im.alpha_composite(e, ((100 - e.width) // 2, (100 - e.height) // 2))
    im.save(os.path.join(OUT, name), optimize=True)
print(len(ICONS), 'images ->', os.path.normpath(OUT))
