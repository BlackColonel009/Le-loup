"""Collections, temporary access and editorial offers. No payment processing."""

import hashlib
import json
import time
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from .administration import audit
from .community import Store, administrator, authenticated, store

router = APIRouter(tags=["collection"])
Database = Annotated[Store, Depends(store)]
User = Annotated[dict, Depends(authenticated)]
Admin = Annotated[dict, Depends(administrator)]
ROLES = {
    "villager": "Villageois",
    "villager_female": "Villageoise",
    "werewolf": "Loup-Garou",
    "seer": "Voyante",
    "witch": "Sorcière",
    "hunter": "Chasseur",
    "little_girl": "Petite Fille",
    "metamorph": "Métamorphe",
    "cupid": "Cupidon",
    "guardian": "Salvateur",
    "elder": "Ancien",
    "scapegoat": "Bouc émissaire",
    "alpha_wolf": "Grand Méchant Loup",
    "white_wolf": "Loup Blanc",
    "wolf_father": "Père des Loups",
    "idiot": "Idiot du Village",
    "piper": "Joueur de Flûte",
    "angel": "Ange",
    "sisters": "Sœurs",
    "mayor": "Maire",
}
VOICES = [
    "intense_male",
    "intense_female",
    "duke",
    "old_wizard",
    "old_witch",
    "werewolf",
    "ghost",
    "cold_killer",
]
VOICE_LABELS = dict(
    zip(
        VOICES,
        [
            "Voix grave masculine",
            "Voix grave féminine",
            "Le Duc",
            "Vieux Sorcier",
            "Vieille Sorcière",
            "Loup-Garou",
            "Fantôme",
            "Tueur de sang-froid",
        ],
        strict=True,
    )
)


def initialize(db):
    with db.db() as c:
        c.executescript("""
            CREATE TABLE IF NOT EXISTS collection_products(
              id TEXT PRIMARY KEY,kind TEXT NOT NULL,theme TEXT NOT NULL,role_id TEXT NOT NULL,
              title TEXT NOT NULL,price_minor INTEGER,currency TEXT NOT NULL DEFAULT 'XOF',
              visible INTEGER NOT NULL DEFAULT 1,shop INTEGER NOT NULL DEFAULT 1,
              collector INTEGER NOT NULL DEFAULT 1,bonus TEXT NOT NULL DEFAULT '[]');
            CREATE TABLE IF NOT EXISTS collection_owned(
              user_id INTEGER NOT NULL,product_id TEXT NOT NULL,source TEXT NOT NULL,
              acquired REAL NOT NULL,PRIMARY KEY(user_id,product_id));
            CREATE TABLE IF NOT EXISTS collection_trials(
              id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,starts TEXT NOT NULL,
              ends TEXT NOT NULL,products TEXT NOT NULL,enabled INTEGER NOT NULL DEFAULT 1);
            CREATE TABLE IF NOT EXISTS collection_days(
              day TEXT PRIMARY KEY,products TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS collection_visits(user_id INTEGER PRIMARY KEY,day TEXT NOT NULL);
        """)
        c.execute("INSERT OR IGNORE INTO settings VALUES('collection_free_access','1')")
        c.execute("INSERT OR IGNORE INTO settings VALUES('collection_free_days','30')")
        c.execute(
            "INSERT OR IGNORE INTO settings VALUES('collection_free_until',?)",
            ((datetime.now(UTC).date() + timedelta(days=29)).isoformat(),),
        )
        for theme in ["classic", "intense", "horror"]:
            for role, name in ROLES.items():
                c.execute(
                    "INSERT OR IGNORE INTO collection_products(id,kind,theme,role_id,title,collector,shop) VALUES(?,'card',?,?,?,?,?)",
                    (
                        f"card-{theme}-{role}",
                        theme,
                        role,
                        name,
                        int(theme != "classic"),
                        int(theme != "classic"),
                    ),
                )
        for voice in VOICES:
            c.execute(
                "INSERT OR IGNORE INTO collection_products(id,kind,theme,role_id,title) VALUES(?,'voice',?,?,?)",
                (
                    f"voice-{voice}",
                    "intense" if voice in VOICES[:3] else "horror",
                    voice,
                    f"Voix · {VOICE_LABELS[voice]}",
                ),
            )
        for theme in ["intense", "horror"]:
            c.execute(
                "INSERT OR IGNORE INTO collection_products(id,kind,theme,role_id,title) VALUES(?,'theme',?,'',?)",
                (f"theme-{theme}", theme, f"Environnement {theme.title()}"),
            )


def free_access(c):
    enabled = (
        c.execute(
            "SELECT value FROM settings WHERE key='collection_free_access'"
        ).fetchone()[0]
        == "1"
    )
    until = c.execute(
        "SELECT value FROM settings WHERE key='collection_free_until'"
    ).fetchone()[0]
    return enabled and datetime.now(UTC).date().isoformat() <= until


def products(c):
    return [
        {**dict(p), "bonus": json.loads(p["bonus"])}
        for p in c.execute("SELECT * FROM collection_products ORDER BY kind,theme,id")
    ]


def day_offers(c, day):
    saved = c.execute(
        "SELECT products FROM collection_days WHERE day=?", (day,)
    ).fetchone()
    if saved:
        return json.loads(saved[0])
    eligible = [
        p
        for p in products(c)
        if p["visible"] and p["collector"] and p["theme"] != "classic"
    ]
    # Deterministic UTC date: all accounts and all processes see the same selection.
    ordered = sorted(
        eligible, key=lambda p: hashlib.sha256(f"{day}:{p['id']}".encode()).digest()
    )
    selected = [p["id"] for p in ordered if p["kind"] == "card"][:5]
    seed = int(hashlib.sha256(day.encode()).hexdigest()[:8], 16)
    for kind, divisor in [("voice", 10), ("theme", 20)]:
        extra = next((p["id"] for p in ordered if p["kind"] == kind), None)
        if seed % divisor == 0 and extra:
            selected.append(extra)
    c.execute(
        "INSERT OR IGNORE INTO collection_days VALUES(?,?)", (day, json.dumps(selected))
    )
    return selected


def trial_ids(c, day):
    rows = c.execute(
        "SELECT products FROM collection_trials WHERE enabled=1 AND starts<=? AND ends>=?",
        (day, day),
    )
    selected = set()
    for row in rows:
        values = json.loads(row[0])
        if not values:
            return {p["id"] for p in products(c)}
        selected.update(values)
    return selected


def view(c, uid=None):
    day = datetime.now(UTC).date().isoformat()
    free = free_access(c)
    trials = trial_ids(c, day)
    owned = (
        {
            r[0]
            for r in c.execute(
                "SELECT product_id FROM collection_owned WHERE user_id=?", (uid,)
            )
        }
        if uid
        else set()
    )
    offers = day_offers(c, day)
    until = c.execute(
        "SELECT value FROM settings WHERE key='collection_free_until'"
    ).fetchone()[0]
    configured_days = int(
        c.execute(
            "SELECT value FROM settings WHERE key='collection_free_days'"
        ).fetchone()[0]
    )
    remaining = (
        max(0, (date.fromisoformat(until) - date.fromisoformat(day)).days + 1)
        if free
        else 0
    )
    active_trials = [
        (json.loads(t["products"]), t["ends"])
        for t in c.execute(
            "SELECT products,ends FROM collection_trials WHERE enabled=1 AND starts<=? AND ends>=?",
            (day, day),
        )
    ]
    result = []
    for p in products(c):
        baseline = p["theme"] == "classic"
        possessed = baseline or p["id"] in owned
        access = possessed or free or p["id"] in trials
        ends = [end for ids, end in active_trials if not ids or p["id"] in ids]
        if free:
            ends.append(until)
        days = (
            max(0, (date.fromisoformat(max(ends)) - date.fromisoformat(day)).days + 1)
            if ends
            else 0
        )
        result.append(
            {
                **p,
                "owned": possessed,
                "accessible": access,
                "locked": not access,
                "free_days_remaining": days if not possessed else None,
                "access_reason": "owned"
                if possessed
                else "free_preview"
                if free
                else "trial"
                if p["id"] in trials
                else "locked",
                "claimable": bool(
                    uid
                    and not possessed
                    and p["visible"]
                    and (p["shop"] or (p["collector"] and p["id"] in offers))
                    and p["price_minor"] is not None
                    and (free or p["price_minor"] == 0)
                ),
                "purchase_label": "Ajouter gratuitement"
                if free or p["price_minor"] == 0
                else "Paiement à venir",
            }
        )
    return {
        "free_access": free,
        "free_until": until,
        "free_days_remaining": remaining,
        "free_days_configured": configured_days,
        "payments_enabled": False,
        "day": day,
        "rotation_timezone": "UTC",
        "products": result,
        "daily_ids": offers,
        "next_rotation": f"{date.fromordinal(date.fromisoformat(day).toordinal() + 1).isoformat()}T00:00:00Z",
    }


@router.get("/collection/catalog")
def catalog(*, db: Database):
    with db.db() as c:
        data = view(c)
        data["products"] = [p for p in data["products"] if p["visible"]]
        return data


@router.get("/collection/me")
def mine(*, user: User, db: Database):
    with db.db() as c:
        data = view(c, user["id"])
        data["user_id"] = user["id"]
        data["products"] = [p for p in data["products"] if p["visible"] or p["owned"]]
        return data


class Claim(BaseModel):
    product_id: str = Field(min_length=1, max_length=80)
    source: Literal["shop", "collector"] = "shop"


@router.post("/collection/claim")
def claim(data: Claim, *, user: User, db: Database):
    with db.db() as c:
        c.execute("BEGIN IMMEDIATE")
        state = view(c, user["id"])
        item = next((p for p in state["products"] if p["id"] == data.product_id), None)
        if not item or not item["visible"] or not item[data.source]:
            raise HTTPException(404, "Article indisponible.")
        if data.source == "collector" and item["id"] not in state["daily_ids"]:
            raise HTTPException(
                409, "Cette offre du Collectionneur n’est plus disponible aujourd’hui."
            )
        if item["owned"]:
            return {"ok": True, "already_owned": True, "granted": []}
        if item["price_minor"] is None:
            raise HTTPException(
                409, "L’administrateur doit publier un prix avant cet ajout."
            )
        if not item["claimable"]:
            raise HTTPException(
                409, "Paiements indisponibles. Aucun montant n’a été débité."
            )
        granted = []
        for pid in dict.fromkeys([item["id"], *item["bonus"]]):
            if not c.execute(
                "SELECT 1 FROM collection_products WHERE id=?", (pid,)
            ).fetchone():
                continue
            c.execute(
                "INSERT OR IGNORE INTO collection_owned VALUES(?,?,?,?)",
                (user["id"], pid, data.source, time.time()),
            )
            if c.execute("SELECT changes()").fetchone()[0]:
                granted.append(pid)
        if granted:
            c.execute(
                "INSERT INTO purchase_history(user_id,product_id,title,amount_minor,currency,status,purchased_at,receipt_reference) VALUES(?,?,?,?,?,?,?,?)",
                (
                    user["id"],
                    item["id"],
                    item["title"],
                    0,
                    item["currency"],
                    "free",
                    time.time(),
                    f"free:{user['id']}:{item['id']}",
                ),
            )
        return {"ok": True, "granted": granted, "amount_charged": 0}


@router.post("/collection/collector/visit")
def collector_visit(*, user: User, db: Database):
    day = datetime.now(UTC).date().isoformat()
    with db.db() as c:
        c.execute("BEGIN IMMEDIATE")
        previous = c.execute(
            "SELECT day FROM collection_visits WHERE user_id=?", (user["id"],)
        ).fetchone()
        show = previous is None or previous["day"] != day
        if show:
            c.execute(
                "INSERT OR REPLACE INTO collection_visits VALUES(?,?)",
                (user["id"], day),
            )
    return {"show": show, "day": day}


class Settings(BaseModel):
    free_access: bool
    free_days: int | None = Field(default=None, ge=1, le=3650)


@router.get("/community/admin/collection")
def admin_state(*, admin: Admin, db: Database):
    with db.db() as c:
        return {
            **view(c),
            "trials": [
                dict(r) | {"products": json.loads(r["products"])}
                for r in c.execute(
                    "SELECT * FROM collection_trials ORDER BY starts DESC"
                )
            ],
        }


@router.put("/community/admin/collection/settings")
def settings(data: Settings, *, admin: Admin, db: Database):
    with db.db() as c:
        current_until = c.execute(
            "SELECT value FROM settings WHERE key='collection_free_until'"
        ).fetchone()[0]
        today = datetime.now(UTC).date()
        if data.free_days is not None:
            c.execute(
                "UPDATE settings SET value=? WHERE key='collection_free_days'",
                (str(data.free_days),),
            )
        if data.free_days is not None or (
            data.free_access and current_until < today.isoformat()
        ):
            days = data.free_days or int(
                c.execute(
                    "SELECT value FROM settings WHERE key='collection_free_days'"
                ).fetchone()[0]
            )
            c.execute(
                "UPDATE settings SET value=? WHERE key='collection_free_until'",
                ((today + timedelta(days=days - 1)).isoformat(),),
            )
        c.execute(
            "UPDATE settings SET value=? WHERE key='collection_free_access'",
            ("1" if data.free_access else "0",),
        )
        audit(c, admin, "collection.settings", data.model_dump_json())
    return {"ok": True}


class ProductEdit(BaseModel):
    price_minor: int | None = Field(default=None, ge=0, le=100000000)
    currency: Literal["XOF", "EUR", "USD"] = "XOF"
    visible: bool = True
    shop: bool = True
    collector: bool = True
    bonus: list[str] = Field(default_factory=list, max_length=10)


@router.put("/community/admin/collection/products/{pid}")
def edit_product(pid: str, data: ProductEdit, *, admin: Admin, db: Database):
    with db.db() as c:
        row = c.execute(
            "SELECT * FROM collection_products WHERE id=?", (pid,)
        ).fetchone()
        if not row:
            raise HTTPException(404, "Produit introuvable.")
        if row["theme"] == "classic":
            raise HTTPException(
                409, "Les cartes classiques restent acquises automatiquement."
            )
        if pid in data.bonus or len(data.bonus) != len(set(data.bonus)):
            raise HTTPException(422, "Bonus dupliqué ou identique au produit.")
        for bid in data.bonus:
            if not c.execute(
                "SELECT 1 FROM collection_products WHERE id=?", (bid,)
            ).fetchone():
                raise HTTPException(422, "Bonus introuvable.")
        c.execute(
            "UPDATE collection_products SET price_minor=?,currency=?,visible=?,shop=?,collector=?,bonus=? WHERE id=?",
            (
                data.price_minor,
                data.currency,
                data.visible,
                data.shop,
                data.collector,
                json.dumps(data.bonus),
                pid,
            ),
        )
        audit(c, admin, "collection.product", pid)
    return {"ok": True}


class Trial(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    starts: date
    ends: date
    products: list[str] = Field(default_factory=list, max_length=100)
    enabled: bool = True


@router.post("/community/admin/collection/trials")
def add_trial(data: Trial, *, admin: Admin, db: Database):
    if data.ends < data.starts:
        raise HTTPException(422, "La fin doit suivre le début.")
    with db.db() as c:
        for pid in data.products:
            if not c.execute(
                "SELECT 1 FROM collection_products WHERE id=?", (pid,)
            ).fetchone():
                raise HTTPException(422, "Produit d’essai introuvable.")
        c.execute(
            "INSERT INTO collection_trials(title,starts,ends,products,enabled) VALUES(?,?,?,?,?)",
            (
                data.title.strip(),
                data.starts.isoformat(),
                data.ends.isoformat(),
                json.dumps(data.products),
                data.enabled,
            ),
        )
        audit(c, admin, "collection.trial", data.model_dump_json())
    return {"ok": True}


@router.delete("/community/admin/collection/trials/{tid}")
def remove_trial(tid: int, *, admin: Admin, db: Database):
    with db.db() as c:
        c.execute("DELETE FROM collection_trials WHERE id=?", (tid,))
        audit(c, admin, "collection.trial.remove", tid)
    return {"ok": True}


class Daily(BaseModel):
    day: date
    products: list[str] = Field(min_length=5, max_length=7)


@router.put("/community/admin/collection/daily")
def edit_daily(data: Daily, *, admin: Admin, db: Database):
    with db.db() as c:
        items = [
            c.execute(
                "SELECT * FROM collection_products WHERE id=? AND visible=1 AND collector=1 AND theme!=?",
                (pid, "classic"),
            ).fetchone()
            for pid in data.products
        ]
        if len(set(data.products)) != len(items) or any(p is None for p in items):
            raise HTTPException(422, "Sélection invalide.")
        counts = {
            kind: sum(p["kind"] == kind for p in items)
            for kind in ["card", "voice", "theme"]
        }
        if counts["card"] != 5 or counts["voice"] > 1 or counts["theme"] > 1:
            raise HTTPException(
                422, "Choisis cinq cartes, et au plus une voix et un thème."
            )
        c.execute(
            "INSERT OR REPLACE INTO collection_days VALUES(?,?)",
            (data.day.isoformat(), json.dumps(data.products)),
        )
        audit(c, admin, "collection.daily", data.model_dump_json())
    return {"ok": True}


def require_room_access(db, uid, pack, card_styles=None, deck=None, voice=None):
    """The host's collection grants the room's cosmetics, not different powers."""
    with db.db() as c:
        if free_access(c):
            return
        state = view(c, uid)
        allowed = {p["id"] for p in state["products"] if p["accessible"]}
        required = []
        if pack in ["intense", "horror"]:
            required.append(f"theme-{pack}")
        for role, count in (deck or {}).items():
            for index in range(count):
                style = (card_styles or {}).get(
                    f"{role}#{index}", (card_styles or {}).get(role, pack)
                )
                if style in ["intense", "horror"]:
                    required.append(f"card-{style}-{role}")
        if voice in VOICES:
            required.append(f"voice-{voice}")
        if any(pid not in allowed for pid in required):
            raise HTTPException(
                403,
                "Ce thème, cette carte ou cette voix n’est pas accessible dans ta collection. "
                "L’accès gratuit est désactivé ou terminé et aucun essai actif ne couvre ce contenu. "
                "Choisis un contenu disponible dans ta collection ou consulte la boutique. "
                "Télécharger les fichiers ne déverrouille pas ce contenu.",
            )
