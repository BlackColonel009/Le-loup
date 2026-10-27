"""Conservative word boundaries, no filtering in private support conversations."""

import re
import time
import unicodedata

WORDS = {
    "con",
    "cons",
    "connard",
    "connards",
    "connasse",
    "connasses",
    "salope",
    "salopes",
    "pute",
    "putes",
    "putain",
    "merde",
    "enfoire",
    "enfoires",
    "encule",
    "encules",
    "batard",
    "batards",
    "bite",
    "bites",
    "chatte",
    "chattes",
    "couille",
    "couilles",
    "nibards",
    "penis",
    "vagin",
    "porno",
    "pornographie",
    "sexe",
    "sexuel",
    "sexuelle",
    "baiser",
    "branler",
    "masturbation",
}


def discouraged(text):
    value = "".join(
        c
        for c in unicodedata.normalize("NFKD", text.casefold())
        if not unicodedata.combining(c)
    )
    value = value.translate(
        str.maketrans(
            {
                "0": "o",
                "1": "i",
                "3": "e",
                "4": "a",
                "5": "s",
                "7": "t",
                "@": "a",
                "$": "s",
            }
        )
    )
    # Rejoin explicit letter-by-letter obfuscation, but never match inside ordinary words.
    value = re.sub(
        r"\b(?:[a-z][.\-_ ]+){2,}[a-z]\b", lambda m: re.sub("[^a-z]", "", m[0]), value
    )
    return bool(WORDS.intersection(re.findall(r"[a-z]+", value)))


def check_message(connection, user_id, text):
    connection.execute("BEGIN IMMEDIATE")
    user = connection.execute(
        "SELECT strikes,muted_until FROM users WHERE id=?", (user_id,)
    ).fetchone()
    now = time.time()
    if user["muted_until"] > now:
        return (
            423,
            "Ton accès au chat est restreint pendant 3 h. Tu peux toujours lire et contacter le support privé.",
        )
    if discouraged(text):
        strikes = user["strikes"] + 1
        until = now + 10800 if strikes >= 3 else 0
        connection.execute(
            "UPDATE users SET strikes=?,muted_until=? WHERE id=?",
            (0 if until else strikes, until, user_id),
        )
        if until:
            return (
                423,
                "Trois avertissements consécutifs : ton accès au chat est restreint pendant 3 h. Le support privé reste accessible.",
            )
        return (
            422,
            f"Message non publié : évite les insultes et les termes sexuels. Avertissement {strikes}/3. Reformule ton message.",
        )
    connection.execute(
        "UPDATE users SET strikes=0,muted_until=0 WHERE id=?", (user_id,)
    )
    return None
