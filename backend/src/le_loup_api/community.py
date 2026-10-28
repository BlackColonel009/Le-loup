"""Persistent community accounts, public discussion and private support tickets."""

import hashlib
import hmac
import os
import secrets
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

router = APIRouter(prefix="/community", tags=["community"])


class Credentials(BaseModel):
    nickname: str = Field(min_length=2, max_length=254)
    password: str = Field(min_length=8, max_length=128)


class Registration(Credentials):
    nickname: str = Field(min_length=2, max_length=24)
    email: str = Field(min_length=3, max_length=254)


class Message(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class Ticket(BaseModel):
    subject: str = Field(min_length=1, max_length=100)
    text: str = Field(min_length=1, max_length=4000)


class OfficialContent(BaseModel):
    kind: Literal["announcement", "faq"]
    title: str = Field(min_length=1, max_length=160)
    body: str = Field(min_length=1, max_length=6000)


class Store:
    def __init__(self, path):
        self.path = str(path)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.limits = {}
        with self.db() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY, nickname TEXT NOT NULL,
                    name_key TEXT NOT NULL UNIQUE, salt TEXT NOT NULL, password TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS sessions (
                    digest TEXT PRIMARY KEY, user_id INTEGER NOT NULL, expires REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL,
                    text TEXT NOT NULL, created REAL NOT NULL, hidden INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS tickets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL,
                    subject TEXT NOT NULL, created REAL NOT NULL, status TEXT NOT NULL DEFAULT 'open');
                CREATE TABLE IF NOT EXISTS replies (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, ticket_id INTEGER NOT NULL,
                    author TEXT NOT NULL, text TEXT NOT NULL, created REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS reports (
                    message_id INTEGER NOT NULL, user_id INTEGER NOT NULL, created REAL NOT NULL,
                    UNIQUE(message_id,user_id));
                CREATE TABLE IF NOT EXISTS official_content (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
                    title TEXT NOT NULL, body TEXT NOT NULL, published REAL NOT NULL,
                    visible INTEGER NOT NULL DEFAULT 1);
                CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY,value TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS offers (id TEXT PRIMARY KEY,title TEXT NOT NULL,
                    category TEXT NOT NULL,description TEXT NOT NULL,price_minor INTEGER NOT NULL DEFAULT 0,
                    currency TEXT NOT NULL DEFAULT 'EUR',visible INTEGER NOT NULL DEFAULT 1,on_sale INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS admin_audit(id INTEGER PRIMARY KEY,actor INTEGER NOT NULL,
                    action TEXT NOT NULL,target TEXT NOT NULL,created REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS purchase_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL,
                    product_id TEXT NOT NULL,title TEXT NOT NULL,amount_minor INTEGER NOT NULL,
                    currency TEXT NOT NULL,status TEXT NOT NULL,purchased_at REAL NOT NULL,
                    receipt_reference TEXT NOT NULL UNIQUE);
                CREATE TABLE IF NOT EXISTS email_challenges (
                    id TEXT PRIMARY KEY,user_id INTEGER,email TEXT,purpose TEXT NOT NULL,
                    digest TEXT NOT NULL,expires REAL NOT NULL,attempts INTEGER NOT NULL,used INTEGER NOT NULL);
            """)
            columns = {row["name"] for row in db.execute("PRAGMA table_info(users)")}
            for name, definition in [
                ("role", "TEXT NOT NULL DEFAULT 'player'"),
                ("banned", "INTEGER NOT NULL DEFAULT 0"),
                ("strikes", "INTEGER NOT NULL DEFAULT 0"),
                ("muted_until", "REAL NOT NULL DEFAULT 0"),
                ("email", "TEXT"),
                ("email_verified", "INTEGER NOT NULL DEFAULT 0"),
            ]:
                if name not in columns:
                    db.execute(f"ALTER TABLE users ADD COLUMN {name} {definition}")
            db.execute("CREATE UNIQUE INDEX IF NOT EXISTS user_email ON users(email)")
            from .shop import PRODUCTS

            for item in PRODUCTS:
                db.execute(
                    "INSERT OR IGNORE INTO offers(id,title,category,description) VALUES(?,?,?,?)",
                    (item["id"], item["title"], item["category"], item["description"]),
                )
            if not db.execute("SELECT id FROM official_content LIMIT 1").fetchone():
                for kind, title, body in [
                    (
                        "announcement",
                        "Bienvenue dans la communauté",
                        "Partagez vos idées, posez vos questions et retrouvez les nouvelles du jeu ici. Pour un problème personnel, utilisez le support privé. Réponse visée sous 48 h.",
                    ),
                    (
                        "faq",
                        "Les thèmes changent-ils les pouvoirs ?",
                        "Non. Classique, Intense et Horreur utilisent les mêmes rôles et règles. Seul leur habillage change.",
                    ),
                    (
                        "faq",
                        "Comment rejoindre une partie en ligne ?",
                        "Choisis Jouer en ligne et saisis le code à six chiffres partagé par le maître du jeu. Une connexion Internet est nécessaire.",
                    ),
                    (
                        "faq",
                        "Comment contacter le support ?",
                        "Connecte-toi à la communauté, ouvre Support privé puis décris ton problème et ton appareil. Tu retrouveras la réponse dans Mes demandes. Réponse visée sous 48 h.",
                    ),
                    (
                        "faq",
                        "Puis-je acheter un thème maintenant ?",
                        "Les achats ne sont pas encore disponibles. Profitez de l’application totalement disponible pour le moment.",
                    ),
                ]:
                    db.execute(
                        "INSERT INTO official_content(kind,title,body,published) VALUES(?,?,?,?)",
                        (kind, title, body, time.time()),
                    )

    @contextmanager
    def db(self):
        # Each request uses its own connection; sqlite's transaction handles concurrent writes.
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def limit(self, key, count, seconds):
        now = time.monotonic()
        # Store only fixed windows, bounded under repeated attempts.
        if len(self.limits) > 10000:
            self.limits = {k: v for k, v in self.limits.items() if v[0] > now}
        deadline, used = self.limits.get(key, (now + seconds, 0))
        if deadline <= now:
            deadline, used = now + seconds, 0
        if used >= count:
            raise HTTPException(429, "Trop de tentatives. Réessaie un peu plus tard.")
        self.limits[key] = deadline, used + 1


def store(request: Request):
    return request.app.state.community


def identity(
    *, authorization: str = Header(default=""), db: Annotated[Store, Depends(store)]
):
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Connecte-toi à la communauté.")
    token = authorization[7:]
    with db.db() as connection:
        user = connection.execute(
            """SELECT users.id, nickname,role,banned,strikes,muted_until,email,email_verified FROM users JOIN sessions
            ON users.id=sessions.user_id WHERE digest=? AND expires>?""",
            (hashlib.sha256(token.encode()).hexdigest(), time.time()),
        ).fetchone()
    if user is None:
        raise HTTPException(401, "Session expirée. Reconnecte-toi.")
    if user["banned"]:
        raise HTTPException(
            403,
            "Compte banni de la communauté. Contacte le support pour contester cette décision.",
        )
    return dict(user)


def authenticated(
    *, authorization: str = Header(default=""), db: Annotated[Store, Depends(store)]
):
    user = identity(authorization=authorization, db=db)
    if not user["email_verified"]:
        raise HTTPException(
            403, "Vérifie ton adresse email pour accéder à la communauté."
        )
    return user


def administrator(
    *, authorization: str = Header(default=""), db: Annotated[Store, Depends(store)]
):
    token = os.getenv("LE_LOUP_SUPPORT_TOKEN", "")
    if token and hmac.compare_digest(authorization, "Bearer " + token):
        return {"id": 0, "role": "admin"}
    try:
        user = authenticated(authorization=authorization, db=db)
    except HTTPException:
        raise HTTPException(403, "Accès réservé à l’administration.") from None
    if user["role"] != "admin":
        raise HTTPException(403, "Accès réservé à l’administration.")
    return user


def session(db, user):
    token = secrets.token_urlsafe(32)
    expires_at = time.time() + 86400
    with db.db() as connection:
        profile = connection.execute(
            "SELECT id,nickname,role,banned,email,email_verified FROM users WHERE id=?",
            (user["id"],),
        ).fetchone()
        if profile["banned"]:
            raise HTTPException(403, "Compte banni de la communauté.")
        connection.execute("DELETE FROM sessions WHERE expires<?", (time.time(),))
        connection.execute(
            "INSERT INTO sessions VALUES(?,?,?)",
            (
                hashlib.sha256(token.encode()).hexdigest(),
                user["id"],
                expires_at,
            ),
        )
    return {
        "token": token,
        "expires_at": expires_at,
        "user": {
            "id": profile["id"],
            "nickname": profile["nickname"],
            "role": profile["role"],
            "verified": profile["role"] == "admin",
            "email": profile["email"],
            "email_verified": bool(profile["email_verified"]),
        },
    }


@router.post("/register", status_code=201)
def register(
    *, data: Registration, request: Request, db: Annotated[Store, Depends(store)]
):
    from .email_security import normalize_email, require_mailer

    require_mailer()
    email = normalize_email(data.email)
    db.limit(("register", request.client.host), 10, 3600)
    name = data.nickname.strip()
    if len(name) < 2:
        raise HTTPException(422, "Pseudo de 2 à 24 caractères requis.")
    salt = secrets.token_hex(16)
    password = hashlib.scrypt(
        data.password.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1
    ).hex()
    try:
        with db.db() as connection:
            result = connection.execute(
                "INSERT INTO users(nickname,name_key,salt,password,email) VALUES(?,?,?,?,?)",
                (name, name.casefold(), salt, password, email),
            )
            user = {"id": result.lastrowid, "nickname": name}
    except sqlite3.IntegrityError:
        raise HTTPException(409, "Ce pseudo ou cet email est déjà utilisé.") from None
    from .email_security import issue

    challenge = issue(db, user["id"], email, "verify")
    return {
        **session(db, user),
        "verification_required": True,
        "challenge_id": challenge,
    }


@router.post("/login")
def login(*, data: Credentials, request: Request, db: Annotated[Store, Depends(store)]):
    db.limit(("login", request.client.host), 20, 60)
    identifier = data.nickname.strip().casefold()
    with db.db() as connection:
        user = connection.execute(
            "SELECT * FROM users WHERE name_key=? OR email=? "
            "ORDER BY (name_key=?) DESC LIMIT 1",
            (identifier, identifier, identifier),
        ).fetchone()
    # Do the same expensive derivation even for unknown accounts.
    salt = user["salt"] if user else "00" * 16
    password = hashlib.scrypt(
        data.password.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1
    ).hex()
    if user is None or not hmac.compare_digest(password, user["password"]):
        raise HTTPException(401, "Pseudo, email ou mot de passe incorrect.")
    result = session(db, user)
    if not user["email_verified"]:
        result["verification_required"] = True
        if user["email"]:
            from .email_security import issue

            db.limit(("verify", user["id"]), 3, 300)
            result["challenge_id"] = issue(db, user["id"], user["email"], "verify")
    return result


@router.post("/logout")
def logout(
    *,
    authorization: str = Header(default=""),
    user: Annotated[dict, Depends(identity)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        connection.execute(
            "DELETE FROM sessions WHERE digest=?",
            (hashlib.sha256(authorization[7:].encode()).hexdigest(),),
        )
    return {"ok": True}


@router.get("/messages")
def messages(
    *,
    after: int = 0,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        # Latest page for the first visit, chronological incremental pages afterwards.
        if after <= 0:
            rows = connection.execute("""SELECT messages.id,nickname,role,text,created FROM messages
                JOIN users ON users.id=user_id WHERE hidden=0 ORDER BY messages.id DESC LIMIT 50""").fetchall()[
                ::-1
            ]
        else:
            rows = connection.execute(
                """SELECT messages.id,nickname,role,text,created FROM messages
                JOIN users ON users.id=user_id WHERE hidden=0 AND messages.id>?
                ORDER BY messages.id LIMIT 50""",
                (after,),
            ).fetchall()
    return {"messages": [dict(row) for row in rows]}


@router.post("/messages", status_code=201)
def post_message(
    *,
    data: Message,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    text = data.text.strip()
    if not text:
        raise HTTPException(422, "Écris un message.")
    from .stickers import validate_sticker

    try:
        sticker = validate_sticker(text)
    except ValueError as error:
        raise HTTPException(422, str(error)) from error
    with db.db() as connection:
        from .moderation import check_message

        warning = check_message(connection, user["id"], "[sticker]" if sticker else text)
        if warning is None:
            db.limit(("post", user["id"]), 1, 2)
            result = connection.execute(
                "INSERT INTO messages(user_id,text,created) VALUES(?,?,?)",
                (user["id"], text, time.time()),
            )
    if warning:
        raise HTTPException(warning[0], warning[1])
    return {"id": result.lastrowid}


@router.post("/messages/{message_id}/report")
def report(
    *,
    message_id: int,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        if (
            connection.execute(
                "SELECT id FROM messages WHERE id=?", (message_id,)
            ).fetchone()
            is None
        ):
            raise HTTPException(404, "Message introuvable.")
        connection.execute(
            "INSERT OR IGNORE INTO reports VALUES(?,?,?)",
            (message_id, user["id"], time.time()),
        )
    return {"ok": True}


@router.post("/tickets", status_code=201)
def create_ticket(
    *,
    data: Ticket,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    if not data.subject.strip() or not data.text.strip():
        raise HTTPException(422, "Sujet et description requis.")
    db.limit(("ticket", user["id"]), 5, 3600)
    with db.db() as connection:
        result = connection.execute(
            "INSERT INTO tickets(user_id,subject,created) VALUES(?,?,?)",
            (user["id"], data.subject.strip(), time.time()),
        )
        connection.execute(
            "INSERT INTO replies(ticket_id,author,text,created) VALUES(?,?,?,?)",
            (result.lastrowid, "player", data.text.strip(), time.time()),
        )
    return {"id": result.lastrowid, "response_target_hours": 48}


@router.get("/tickets")
def tickets(
    *,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        rows = connection.execute(
            "SELECT id,subject,created,status FROM tickets WHERE user_id=? ORDER BY id DESC LIMIT 50",
            (user["id"],),
        ).fetchall()
    return {"tickets": [dict(row) for row in rows]}


def ticket_messages(connection, ticket_id):
    return [
        dict(row)
        for row in connection.execute(
            "SELECT author,text,created FROM replies WHERE ticket_id=? ORDER BY id",
            (ticket_id,),
        )
    ]


@router.get("/tickets/{ticket_id}")
def ticket(
    *,
    ticket_id: int,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        row = connection.execute(
            "SELECT id,subject,status FROM tickets WHERE id=? AND user_id=?",
            (ticket_id, user["id"]),
        ).fetchone()
        if not row:
            raise HTTPException(404, "Demande introuvable.")
        return {**dict(row), "messages": ticket_messages(connection, ticket_id)}


@router.post("/tickets/{ticket_id}/reply")
def reply(
    *,
    ticket_id: int,
    data: Message,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    db.limit(("reply", user["id"]), 10, 60)
    with db.db() as connection:
        if not connection.execute(
            "SELECT id FROM tickets WHERE id=? AND user_id=?", (ticket_id, user["id"])
        ).fetchone():
            raise HTTPException(404, "Demande introuvable.")
        if not data.text.strip():
            raise HTTPException(422, "Écris un message.")
        connection.execute(
            "INSERT INTO replies(ticket_id,author,text,created) VALUES(?,?,?,?)",
            (ticket_id, "player", data.text.strip(), time.time()),
        )
    return {"ok": True}


@router.get("/admin/tickets", dependencies=[Depends(administrator)])
def admin_tickets(*, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        rows = connection.execute(
            "SELECT tickets.*,nickname FROM tickets JOIN users ON users.id=user_id ORDER BY tickets.id DESC LIMIT 100"
        ).fetchall()
    return {"tickets": [dict(row) for row in rows]}


@router.get("/admin/tickets/{ticket_id}", dependencies=[Depends(administrator)])
def admin_ticket(*, ticket_id: int, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        return {"messages": ticket_messages(connection, ticket_id)}


@router.post("/admin/tickets/{ticket_id}/reply", dependencies=[Depends(administrator)])
def admin_reply(*, ticket_id: int, data: Message, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        if not connection.execute(
            "SELECT id FROM tickets WHERE id=?", (ticket_id,)
        ).fetchone():
            raise HTTPException(404, "Demande introuvable.")
        if not data.text.strip():
            raise HTTPException(422, "Écris une réponse.")
        connection.execute(
            "INSERT INTO replies(ticket_id,author,text,created) VALUES(?,?,?,?)",
            (ticket_id, "support", data.text.strip(), time.time()),
        )
        connection.execute(
            "UPDATE tickets SET status='answered' WHERE id=?", (ticket_id,)
        )
    return {"ok": True}


@router.get("/admin/reports", dependencies=[Depends(administrator)])
def admin_reports(*, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        rows = connection.execute(
            "SELECT message_id,count(*) AS reports,text FROM reports JOIN messages ON messages.id=message_id GROUP BY message_id ORDER BY reports DESC LIMIT 100"
        ).fetchall()
    return {"reports": [dict(row) for row in rows]}


@router.delete("/admin/messages/{message_id}", dependencies=[Depends(administrator)])
def hide_message(*, message_id: int, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        connection.execute("UPDATE messages SET hidden=1 WHERE id=?", (message_id,))
    return {"ok": True}


@router.get("/info")
def public_info(*, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        rows = [
            dict(row)
            for row in connection.execute(
                "SELECT id,kind,title,body,published FROM official_content WHERE visible=1 ORDER BY published DESC,id DESC LIMIT 200"
            )
        ]
    return {
        "announcements": [r for r in rows if r["kind"] == "announcement"],
        "faq": [r for r in rows if r["kind"] == "faq"],
    }


@router.post("/admin/content", status_code=201, dependencies=[Depends(administrator)])
def create_content(*, data: OfficialContent, db: Annotated[Store, Depends(store)]):
    if not data.title.strip() or not data.body.strip():
        raise HTTPException(422, "Titre et texte requis.")
    with db.db() as connection:
        result = connection.execute(
            "INSERT INTO official_content(kind,title,body,published) VALUES(?,?,?,?)",
            (data.kind, data.title.strip(), data.body.strip(), time.time()),
        )
    return {"id": result.lastrowid}


@router.put("/admin/content/{content_id}", dependencies=[Depends(administrator)])
def update_content(
    *, content_id: int, data: OfficialContent, db: Annotated[Store, Depends(store)]
):
    if not data.title.strip() or not data.body.strip():
        raise HTTPException(422, "Titre et texte requis.")
    with db.db() as connection:
        result = connection.execute(
            "UPDATE official_content SET kind=?,title=?,body=?,published=? WHERE id=? AND visible=1",
            (data.kind, data.title.strip(), data.body.strip(), time.time(), content_id),
        )
        if result.rowcount == 0:
            raise HTTPException(404, "Publication introuvable.")
    return {"ok": True}


@router.delete("/admin/content/{content_id}", dependencies=[Depends(administrator)])
def delete_content(*, content_id: int, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        connection.execute(
            "UPDATE official_content SET visible=0 WHERE id=?", (content_id,)
        )
    return {"ok": True}
