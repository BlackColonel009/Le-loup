"""Point d'entrée HTTP. Les événements de jeu seront ajoutés séparément."""

from fastapi import FastAPI

app = FastAPI(title="Le Loup API", version="0.1.0")


@app.get("/health", tags=["system"])
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "le-loup-api", "protocol": "1"}

