"""Public preview catalogue. Purchases are intentionally disabled server-side."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from .community import Store, store

router = APIRouter(prefix="/shop", tags=["shop"])
PRODUCTS = [
    {
        "id": "intense",
        "category": "Thèmes complets",
        "title": "Intense Premium",
        "description": "Village enneigé, cartes dorées, maisons, roue et animations du pack.",
    },
    {
        "id": "horror",
        "category": "Thèmes complets",
        "title": "Horreur",
        "description": "Une ambiance sombre et des habillages terrifiants. Collection en préparation.",
    },
    {
        "id": "cards",
        "category": "Apparences de cartes",
        "title": "Collections de cartes",
        "description": "Personnalise les illustrations et les bordures, avec les mêmes pouvoirs.",
    },
    {
        "id": "voices",
        "category": "Voix OFF",
        "title": "Narrateurs et narratrices",
        "description": "Choisis les voix et les interprétations pour accompagner tes parties.",
    },
    {
        "id": "animations",
        "category": "Animations",
        "title": "Effets et cérémonies",
        "description": "Découvre des effets de protection et des cérémonies de sentence.",
    },
    {
        "id": "ghosts",
        "category": "Cosmétiques personnels",
        "title": "Fantômes et ornements",
        "description": "Personnalise ton fantôme et tes ornements visuels.",
    },
]


@router.get("/catalog")
def catalog(*, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        products = [
            dict(row)
            for row in connection.execute(
                "SELECT * FROM offers WHERE visible=1 ORDER BY rowid"
            )
        ]
    return {
        "purchases_enabled": False,
        "notice": "Profitez de l’application totalement disponible pour le moment.",
        "products": [
            {**product, "purchase_label": "Achat à venir", "purchasable": False}
            for product in products
        ],
    }


class Purchase(BaseModel):
    product_id: str = Field(min_length=1, max_length=40)


@router.post("/purchase")
def purchase(data: Purchase, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        exists = connection.execute(
            "SELECT id FROM offers WHERE id=? AND visible=1", (data.product_id,)
        ).fetchone()
    if not exists:
        raise HTTPException(404, "Article introuvable.")
    raise HTTPException(409, "Non disponible. Achat à venir.")
