"""Public card catalogue and a small administrator-only publishing API."""

import base64
import binascii
import io
import re
import uuid
from pathlib import Path
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, Field

from .community import Store, administrator, store

router = APIRouter(tags=["website gallery"])
DB = Annotated[Store, Depends(store)]
Admin = Annotated[dict, Depends(administrator)]


def initialize(db):
    with db.db() as connection:
        connection.execute("""CREATE TABLE IF NOT EXISTS site_cards (
            id TEXT PRIMARY KEY,title TEXT NOT NULL,role_name TEXT NOT NULL,
            edition TEXT NOT NULL,description TEXT NOT NULL,image TEXT NOT NULL,
            published INTEGER NOT NULL DEFAULT 1,position INTEGER NOT NULL DEFAULT 0)""")
        if connection.execute(
            "SELECT value FROM settings WHERE key='site_gallery_seeded'"
        ).fetchone():
            return
        for edition in ("classic", "intense"):
            for position, (key, title, description) in enumerate(
                [
                    (
                        "werewolf",
                        "Le Loup-Garou",
                        "La nuit, il rejoint la meute pour choisir une victime.",
                    ),
                    (
                        "seer",
                        "La Voyante",
                        "Chaque nuit, elle découvre une information secrète sur un joueur.",
                    ),
                    (
                        "witch",
                        "La Sorcière",
                        "Une potion pour sauver, une potion pour éliminer. Chaque potion ne sert qu’une fois.",
                    ),
                ]
            ):
                filename = (
                    f"{key}.jpg" if edition == "classic" else f"{key}-intense.jpg"
                )
                connection.execute(
                    "INSERT INTO site_cards VALUES(?,?,?,?,?,?,1,?)",
                    (
                        uuid.uuid4().hex,
                        title,
                        title,
                        edition,
                        description,
                        "asset:" + filename,
                        position,
                    ),
                )
        connection.execute("INSERT INTO settings VALUES('site_gallery_seeded','1')")


def serialize(row):
    item = dict(row)
    image = item.pop("image")
    item["image_url"] = (
        "/site-assets/" + image[6:]
        if image.startswith("asset:")
        else "/gallery/images/" + image
    )
    item["published"] = bool(item["published"])
    return item


@router.get("/gallery/cards")
def public_cards(*, db: DB):
    with db.db() as connection:
        rows = connection.execute(
            "SELECT * FROM site_cards WHERE published=1 ORDER BY position,title"
        ).fetchall()
    return {"cards": [serialize(row) for row in rows]}


def upload_directory(db):
    return Path(db.path).resolve().parent / "site-uploads"


@router.get("/gallery/images/{filename}")
def image(*, filename: str, db: DB):
    if not re.fullmatch(r"[a-f0-9]{32}\.(png|jpg|webp)", filename):
        raise HTTPException(404, "Image introuvable.")
    with db.db() as connection:
        published = connection.execute(
            "SELECT id FROM site_cards WHERE image=? AND published=1", (filename,)
        ).fetchone()
    path = upload_directory(db) / filename
    if not published or not path.is_file():
        raise HTTPException(404, "Image introuvable.")
    media_type = {".webp": "image/webp", ".png": "image/png", ".jpg": "image/jpeg"}[
        path.suffix
    ]
    return FileResponse(
        path,
        media_type=media_type,
        headers={"X-Content-Type-Options": "nosniff", "Cache-Control": "no-cache"},
    )


class Card(BaseModel):
    title: str = Field(min_length=1, max_length=100, pattern=r"\S")
    role_name: str = Field(min_length=1, max_length=100, pattern=r"\S")
    edition: Literal["classic", "intense", "horror"]
    description: str = Field(min_length=1, max_length=1500, pattern=r"\S")
    published: bool = True
    position: int = Field(default=0, ge=0, le=10000)
    image_base64: str | None = Field(default=None, max_length=5_600_000)


def save_image(db, value):
    try:
        raw = base64.b64decode(value, validate=True)
        if len(raw) > 4 * 1024 * 1024:
            raise ValueError
        with Image.open(io.BytesIO(raw)) as original:
            if original.format not in {"PNG", "JPEG", "WEBP"}:
                raise ValueError
            if (
                max(original.size) > 4096
                or original.width * original.height > 16_000_000
            ):
                raise ValueError
            original.load()
            # Re-encode pixels only, discarding EXIF, scripts and other metadata.
            pixels = original.convert("RGBA" if "A" in original.getbands() else "RGB")
            output = io.BytesIO()
            pixels.save(output, format="WEBP", quality=90, method=4)
    except (
        ValueError,
        binascii.Error,
        OSError,
        UnidentifiedImageError,
        Image.DecompressionBombError,
    ):
        raise HTTPException(
            422,
            "Image PNG, JPEG ou WebP requise : 4 Mo et 4096 pixels de côté maximum.",
        ) from None
    directory = upload_directory(db)
    directory.mkdir(parents=True, exist_ok=True)
    filename = uuid.uuid4().hex + ".webp"
    (directory / filename).write_bytes(output.getvalue())
    return filename


@router.get("/community/admin/site/cards")
def all_cards(*, admin: Admin, db: DB):
    with db.db() as connection:
        rows = connection.execute(
            "SELECT * FROM site_cards ORDER BY edition,position,title"
        ).fetchall()
    return {"cards": [serialize(row) for row in rows]}


@router.post("/community/admin/site/cards", status_code=201)
def create(*, data: Card, admin: Admin, db: DB):
    db.limit(("site_upload", admin["id"]), 30, 300)
    if not data.image_base64:
        raise HTTPException(422, "Ajoute une image à la carte.")
    filename = save_image(db, data.image_base64)
    card_id = uuid.uuid4().hex
    try:
        with db.db() as connection:
            connection.execute(
                "INSERT INTO site_cards VALUES(?,?,?,?,?,?,?,?)",
                (
                    card_id,
                    data.title.strip(),
                    data.role_name.strip(),
                    data.edition,
                    data.description.strip(),
                    filename,
                    int(data.published),
                    data.position,
                ),
            )
    except Exception:
        (upload_directory(db) / filename).unlink(missing_ok=True)
        raise
    return {"id": card_id}


@router.put("/community/admin/site/cards/{card_id}")
def update(*, card_id: str, data: Card, admin: Admin, db: DB):
    db.limit(("site_upload", admin["id"]), 30, 300)
    with db.db() as connection:
        row = connection.execute(
            "SELECT image FROM site_cards WHERE id=?", (card_id,)
        ).fetchone()
        if not row:
            raise HTTPException(404, "Carte introuvable.")
        filename = (
            save_image(db, data.image_base64) if data.image_base64 else row["image"]
        )
        try:
            connection.execute(
                "UPDATE site_cards SET title=?,role_name=?,edition=?,description=?,image=?,published=?,position=? WHERE id=?",
                (
                    data.title.strip(),
                    data.role_name.strip(),
                    data.edition,
                    data.description.strip(),
                    filename,
                    int(data.published),
                    data.position,
                    card_id,
                ),
            )
        except Exception:
            if filename != row["image"]:
                (upload_directory(db) / filename).unlink(missing_ok=True)
            raise
    if filename != row["image"] and not row["image"].startswith("asset:"):
        (upload_directory(db) / row["image"]).unlink(missing_ok=True)
    return {"ok": True}


@router.delete("/community/admin/site/cards/{card_id}")
def delete(*, card_id: str, admin: Admin, db: DB):
    with db.db() as connection:
        row = connection.execute(
            "SELECT image FROM site_cards WHERE id=?", (card_id,)
        ).fetchone()
        if not row:
            raise HTTPException(404, "Carte introuvable.")
        connection.execute("DELETE FROM site_cards WHERE id=?", (card_id,))
    if not row["image"].startswith("asset:"):
        (upload_directory(db) / row["image"]).unlink(missing_ok=True)
    return {"ok": True}
