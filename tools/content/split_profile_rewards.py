"""Separate the two imagegen cutout sheets into downloadable profile assets."""
import json
from pathlib import Path

from PIL import Image
from rgba_components import components, isolate

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'shared/avatars/reward_sources'
OUT = ROOT / 'shared/avatars/rewards'
for kind in ('portraits', 'borders'):
    (OUT / kind).mkdir(parents=True, exist_ok=True)

groups = {
    'legends': [
        ('druid', 'Druide', 'borders'), ('headless-rider', 'Cavalier sans tête', 'portraits'),
        ('alchemist', 'Alchimiste', 'borders'), ('battle-sister', 'Sœur de bataille', 'portraits'), ('shaman', 'Chaman', 'portraits'),
        ('vampire', 'Vampire', 'borders'), ('scarred-wolf', 'Loup-Garou écorché', 'portraits'),
        ('sentinel', 'Sentinelle', 'borders'), ('heretic', 'Hérétique', 'portraits'), ('shadow', 'Ombre', 'borders'),
        ('berserker', 'Berserker', 'borders'), ('witch-queen', 'Reine des Sorcières', 'borders'),
        ('monster-hunter', 'Chasseur de monstres', 'portraits'), ('ghost', 'Fantôme', 'borders'), ('dwarf-artificer', 'Artificier nain', 'borders'),
        ('fallen-paladin', 'Paladin déchu', 'portraits'), ('wolf-lord', 'Seigneur des Loups', 'portraits'),
        ('night-raven', 'Corbeau de la nuit', 'borders'), ('midnight-wolf', 'Loup-Garou de minuit', 'portraits'), ('cursed-archivist', 'Archiviste maudit', 'portraits'),
    ],
    'village': [
        ('villager', 'Villageois', 'borders'), ('wolf', 'Loup-Garou', 'portraits'), ('seer', 'Voyante', 'borders'),
        ('witch', 'Sorcière', 'borders'), ('hunter', 'Chasseur', 'borders'),
        ('little-girl', 'Petite Fille', 'borders'), ('cupid', 'Cupidon', 'borders'), ('guardian', 'Salvateur', 'borders'),
        ('elder', 'Ancien', 'borders'), ('scapegoat', 'Bouc émissaire', 'borders'),
        ('alpha', 'Alpha', 'portraits'), ('white-wolf', 'Loup Blanc', 'portraits'), ('wolf-father', 'Père des Loups', 'borders'),
        ('idiot', 'Idiot du Village', 'borders'), ('piper', 'Joueur de Flûte', 'borders'),
        ('angel', 'Ange', 'borders'), ('metamorph', 'Voleur / Métamorphe', 'portraits'), ('raven', 'Corbeau', 'borders'),
        ('twin-wolves', 'Loups de la légende', 'borders'), ('game-master', 'Maître du jeu', 'portraits'),
    ],
}
entries = []
for sheet, designs in groups.items():
    image = Image.open(SOURCE / f'{sheet}-transparent.png').convert('RGBA')
    # Cut at the measured gaps between rows and columns, preserving ornaments.
    for i, (slug, title, kind) in enumerate(designs):
        row, col = divmod(i, 5)
        nominal_x = [0, 356, 696, 994, 1315, image.width]
        top, bottom = (0, 246, 472, 692, image.height)[row:row+2]
        cell = image.crop((nominal_x[col], top, nominal_x[col+1], bottom))
        parts = components(cell, 500)
        # Keep detached ornament fragments, but discard tiny leftover board specks.
        cut = isolate(cell, parts)
        side = max(cut.size) + 8
        square = Image.new('RGBA', (side, side))
        square.alpha_composite(cut, ((side-cut.width)//2, (side-cut.height)//2))
        ident = f'reward-{sheet}-{slug}'
        target = OUT / kind / f'{ident}.png'
        override = SOURCE / 'overrides' / target.name
        if override.is_file():
            replacement = Image.open(override).convert('RGBA')
            replacement = replacement.crop(replacement.getbbox())
            replacement.thumbnail((384, 384), Image.Resampling.LANCZOS)
            side = max(replacement.size) + 16
            square = Image.new('RGBA', (side, side))
            square.alpha_composite(replacement, ((side-replacement.width)//2, (side-replacement.height)//2))
        square.save(target, optimize=True)
        entry = {'id': ident, 'title': title, 'kind': kind, 'sheet': sheet, 'position': i,
                 'source': target.name, 'pack_id': 'borders-rewards' if kind == 'borders' else 'avatars-rewards',
                 'asset': f"assets/{'borders' if kind == 'borders' else 'avatars'}/rewards/{ident}.png",
                 'unlock': 'challenge'}
        entries.append(entry)
(ROOT / 'shared/avatars/rewards.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f"{sum(e['kind']=='portraits' for e in entries)} profils et {sum(e['kind']=='borders' for e in entries)} bordures séparés.")
