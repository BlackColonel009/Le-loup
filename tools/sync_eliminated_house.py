"""Copie le visuel remplacé dans le dépôt vers les assets Flutter, sans le modifier."""
from pathlib import Path
import hashlib
import shutil
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / 'mordeviel/Map/home_rip.png'
target = root / 'apps/mordeviel/assets/village/house_eliminated.png'
with Image.open(source) as image:
    image.verify()
if target.exists() and hashlib.sha256(source.read_bytes()).digest() == hashlib.sha256(target.read_bytes()).digest():
    print('Maison éliminée déjà à jour ; le fichier source est inchangé.')
else:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    print('Nouveau visuel intégré :', target)

# Métadonnées de cadrage uniquement : aucun pixel source n'est modifié.
geometry = root / 'apps/mordeviel/lib/village/house_sprite_geometry.dart'
lines = [
    '// Généré par tools/sync_eliminated_house.py ; sources PNG conservées intactes.',
    'class HouseSpriteGeometry {',
    '  const HouseSpriteGeometry(this.width, this.height, this.left, this.top, this.visibleWidth, this.visibleHeight);',
    '  final double width, height, left, top, visibleWidth, visibleHeight;',
    '}',
    'const houseSpriteGeometry = <String, HouseSpriteGeometry>{',
]
for state in ['day', 'night', 'eliminated']:
    path = target.parent / f'house_{state}.png'
    with Image.open(path) as image:
        width, height = image.size
        bbox = image.getchannel('A').getbbox() if image.mode == 'RGBA' else (0, 0, width, height)
        if not bbox:
            raise ValueError(f'Image entièrement transparente : {path}')
        left, top, right, bottom = bbox
    numbers = ', '.join(str(n) for n in [width, height, left, top, right-left, bottom-top])
    lines.append(f"  '{state}': HouseSpriteGeometry({numbers}),")
lines.append('};\n')
geometry.write_text('\n'.join(lines), encoding='utf-8')
print('Cadrage des trois maisons mis à jour, sans retoucher les images.')
