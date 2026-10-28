import asyncio

from httpx import ASGITransport, AsyncClient

from mordeviel_api.main import app


def test_health_exposes_protocol_version():
    async def request_health():
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            return await client.get("/health")

    response = asyncio.run(request_health())
    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "mordeviel-api",
        "protocol": "1",
    }
