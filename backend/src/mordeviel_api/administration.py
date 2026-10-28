import time
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from .community import Store, administrator, authenticated, store

router = APIRouter()
MESSAGE = "On est en petite maintenance, s’il vous plaît."


def status(db):
    with db.db() as connection:
        values = {
            row["key"]: row["value"]
            for row in connection.execute("SELECT * FROM settings")
        }
    return {
        "local_enabled": values.get("local_enabled", "1") == "1",
        "online_enabled": values.get("online_enabled", "1") == "1",
        "message": values.get("maintenance_message", MESSAGE),
    }


def audit(connection, admin, action, target):
    connection.execute(
        "INSERT INTO admin_audit(actor,action,target,created) VALUES(?,?,?,?)",
        (admin["id"], action, str(target), time.time()),
    )


@router.get("/status")
def public_status(*, db: Annotated[Store, Depends(store)]):
    return status(db)


@router.get("/community/me")
def me(*, user: Annotated[dict, Depends(authenticated)]):
    return {"user": {**user, "verified": user["role"] == "admin"}}


@router.get("/community/admin/dashboard")
def dashboard(
    *,
    admin: Annotated[dict, Depends(administrator)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        users = [
            dict(row)
            for row in connection.execute(
                "SELECT id,nickname,role,banned,strikes,muted_until FROM users ORDER BY id DESC LIMIT 200"
            )
        ]
        offers = [
            dict(row) for row in connection.execute("SELECT * FROM offers ORDER BY id")
        ]
    return {
        "users": users,
        "offers": offers,
        "maintenance": status(db),
        "payments_available": False,
    }


class Maintenance(BaseModel):
    local_enabled: bool
    online_enabled: bool
    message: str = Field(default=MESSAGE, min_length=1, max_length=240)


@router.put("/community/admin/maintenance")
def maintenance(
    *,
    data: Maintenance,
    admin: Annotated[dict, Depends(administrator)],
    db: Annotated[Store, Depends(store)],
):
    if not data.message.strip():
        raise HTTPException(422, "Message requis.")
    with db.db() as connection:
        for key, value in [
            ("local_enabled", "1" if data.local_enabled else "0"),
            ("online_enabled", "1" if data.online_enabled else "0"),
            ("maintenance_message", data.message.strip()),
        ]:
            connection.execute(
                "INSERT OR REPLACE INTO settings VALUES(?,?)", (key, value)
            )
        audit(connection, admin, "maintenance", data.model_dump_json())
    return status(db)


class AccountAction(BaseModel):
    action: Literal["ban", "unban", "unmute"]


@router.post("/community/admin/users/{user_id}")
def account_action(
    *,
    user_id: int,
    data: AccountAction,
    admin: Annotated[dict, Depends(administrator)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        user = connection.execute(
            "SELECT role FROM users WHERE id=?", (user_id,)
        ).fetchone()
        if user is None:
            raise HTTPException(404, "Compte introuvable.")
        if user["role"] == "admin":
            raise HTTPException(
                409, "Les comptes administrateurs sont protégés contre cette action."
            )
        if data.action == "unmute":
            connection.execute(
                "UPDATE users SET strikes=0,muted_until=0 WHERE id=?", (user_id,)
            )
        else:
            connection.execute(
                "UPDATE users SET banned=? WHERE id=?",
                (1 if data.action == "ban" else 0, user_id),
            )
        audit(connection, admin, data.action, user_id)
    return {"ok": True}


class Offer(BaseModel):
    id: str = Field(pattern=r"^[a-z0-9_-]{1,40}$")
    title: str = Field(min_length=1, max_length=100)
    category: str = Field(min_length=1, max_length=80)
    description: str = Field(min_length=1, max_length=2000)
    price_minor: int = Field(ge=0, le=100000000)
    currency: Literal["EUR", "USD", "XOF"] = "EUR"
    visible: bool = True
    on_sale: bool = False


@router.put("/community/admin/offers/{offer_id}")
def offer(
    *,
    offer_id: str,
    data: Offer,
    admin: Annotated[dict, Depends(administrator)],
    db: Annotated[Store, Depends(store)],
):
    if offer_id != data.id or any(
        not value.strip() for value in [data.title, data.category, data.description]
    ):
        raise HTTPException(422, "Article invalide.")
    with db.db() as connection:
        connection.execute(
            """INSERT INTO offers VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET
          title=excluded.title,category=excluded.category,description=excluded.description,
          price_minor=excluded.price_minor,currency=excluded.currency,visible=excluded.visible,on_sale=excluded.on_sale""",
            (
                data.id,
                data.title.strip(),
                data.category.strip(),
                data.description.strip(),
                data.price_minor,
                data.currency,
                int(data.visible),
                int(data.on_sale),
            ),
        )
        audit(connection, admin, "offer", offer_id)
    return {"ok": True, "payments_available": False}
