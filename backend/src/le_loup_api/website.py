"""Buildless public website, shipped with the API package."""

import os
from pathlib import Path
from typing import Annotated
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, model_validator

from .administration import audit
from .community import Store, administrator, store

WEB = Path(__file__).with_name("web")
router = APIRouter(include_in_schema=False)
HEADERS = {
    "Content-Security-Policy": "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "Cache-Control": "no-store",
}


@router.get("/")
def home():
    return FileResponse(WEB / "index.html", headers=HEADERS)


@router.get("/confidentialite")
def privacy():
    return FileResponse(WEB / "confidentialite.html", headers=HEADERS)


@router.get("/suppression-compte")
def deletion():
    return FileResponse(WEB / "suppression-compte.html", headers=HEADERS)


@router.get("/support")
def support():
    return FileResponse(WEB / "support.html", headers=HEADERS)


@router.get("/administration")
def administration():
    return FileResponse(WEB / "administration.html", headers=HEADERS)


@router.get("/site-config")
def site_config(*, db: Annotated[Store, Depends(store)]):
    # Explicitly public contact only; SMTP credentials are never exposed.
    download = download_settings(db)
    return JSONResponse(
        {
            "support_email": os.getenv("LE_LOUP_PUBLIC_SUPPORT_EMAIL", ""),
            "download_url": download["download_url"]
            if download["download_enabled"]
            else "",
            "download_version": download["download_version"]
            if download["download_enabled"]
            else "",
        },
        headers=HEADERS,
    )


def download_settings(db):
    with db.db() as connection:
        values = dict(
            connection.execute(
                "SELECT key,value FROM settings WHERE key IN ('site_download_url','site_download_enabled','site_download_version')"
            ).fetchall()
        )
    return {
        "download_url": values.get("site_download_url", ""),
        "download_enabled": values.get("site_download_enabled", "0") == "1",
        "download_version": values.get("site_download_version", ""),
    }


class DownloadSettings(BaseModel):
    download_url: str = Field(default="", max_length=2048)
    download_enabled: bool = False
    download_version: str = Field(default="", max_length=40)

    @model_validator(mode="after")
    def validate_download(self):
        self.download_url = self.download_url.strip()
        self.download_version = self.download_version.strip()
        if self.download_url:
            url = urlsplit(self.download_url)
            if (
                url.scheme != "https"
                or not url.hostname
                or url.username
                or url.password
                or any(char.isspace() or ord(char) < 32 for char in self.download_url)
            ):
                raise ValueError(
                    "Utilise un lien de partage HTTPS complet, sans identifiants."
                )
            # Validate malformed ports too, without contacting the destination.
            _ = url.port
        if self.download_enabled and not self.download_url:
            raise ValueError("Ajoute le lien avant d’activer le téléchargement.")
        return self


@router.get("/community/admin/site/download")
def admin_download(
    *,
    admin: Annotated[dict, Depends(administrator)],
    db: Annotated[Store, Depends(store)],
):
    return download_settings(db)


@router.put("/community/admin/site/download")
def save_download(
    *,
    data: DownloadSettings,
    admin: Annotated[dict, Depends(administrator)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        for key, value in (
            ("site_download_url", data.download_url),
            ("site_download_enabled", "1" if data.download_enabled else "0"),
            ("site_download_version", data.download_version),
        ):
            connection.execute(
                "INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (key, value),
            )
        audit(connection, admin, "website_download", "public_download")
    return data.model_dump()


def install(app):
    app.include_router(router)
    app.mount("/site-assets", StaticFiles(directory=WEB / "assets"), name="site-assets")
