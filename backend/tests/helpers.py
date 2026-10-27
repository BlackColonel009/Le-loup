OUTBOX = []


def post_verified(api, path, **kwargs):
    if path == "/community/register":
        data = dict(kwargs["json"])
        data.setdefault(
            "email",
            data["nickname"].strip().casefold().replace(" ", "") + "@example.test",
        )
        kwargs["json"] = data
    response = api.post(path, **kwargs)
    if path in {"/community/register", "/community/login"} and response.status_code in {
        200,
        201,
    }:
        result = response.json()
        if result.get("verification_required") and result.get("challenge_id"):
            code = OUTBOX[-1]["code"]
            verified = api.post(
                "/community/email/verify",
                headers={"Authorization": "Bearer " + result["token"]},
                json={"challenge_id": result["challenge_id"], "code": code},
            )
            assert verified.status_code == 200, verified.text
    return response
