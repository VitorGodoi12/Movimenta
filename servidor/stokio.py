import hashlib
import ipaddress
import json
import os
import secrets
import smtplib
import sqlite3
import ssl
from contextlib import contextmanager
from datetime import date
from email.message import EmailMessage
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen
from urllib.error import HTTPError

DATA = Path(os.environ.get("STOKIO_DATA", "dados"))
SCHEMA = """
CREATE TABLE IF NOT EXISTS users(
 id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE NOT NULL,
 phone TEXT NOT NULL, password TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS stores(
 id TEXT PRIMARY KEY, name TEXT NOT NULL, address TEXT NOT NULL,
 contact TEXT UNIQUE NOT NULL, founder TEXT NOT NULL REFERENCES users(id),
 invite TEXT UNIQUE NOT NULL);
CREATE TABLE IF NOT EXISTS members(
 store TEXT REFERENCES stores(id), user TEXT REFERENCES users(id),
 role TEXT NOT NULL CHECK(role IN ('funcionario','gerente','dono')),
 PRIMARY KEY(store,user));
CREATE TABLE IF NOT EXISTS sessions(
 token TEXT PRIMARY KEY, user TEXT NOT NULL REFERENCES users(id), expires INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS requests(
 store TEXT REFERENCES stores(id), user TEXT REFERENCES users(id),
 status TEXT NOT NULL, emailed INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(store,user));
CREATE TABLE IF NOT EXISTS aisles(
 id TEXT PRIMARY KEY, store TEXT NOT NULL REFERENCES stores(id), name TEXT NOT NULL,
 responsible TEXT REFERENCES users(id), UNIQUE(store,name));
CREATE TABLE IF NOT EXISTS stock(
 id TEXT PRIMARY KEY, store TEXT NOT NULL REFERENCES stores(id),
 name TEXT NOT NULL, category TEXT NOT NULL, barcode TEXT,
 quantity INTEGER NOT NULL CHECK(quantity >= 0), expiration TEXT,
 aisle TEXT REFERENCES aisles(id), revision INTEGER NOT NULL DEFAULT 1, UNIQUE(store,barcode));
CREATE TABLE IF NOT EXISTS local_imports(
 store TEXT NOT NULL REFERENCES stores(id), source TEXT NOT NULL, PRIMARY KEY(store,source));
CREATE TABLE IF NOT EXISTS limits(key TEXT PRIMARY KEY, window INTEGER NOT NULL, hits INTEGER NOT NULL);
"""
CATALOG = """CREATE TABLE IF NOT EXISTS products(
 code TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL, updated INTEGER NOT NULL)"""


class ApiError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


@contextmanager
def database(catalog=False):
    DATA.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(DATA / ("catalogo.sqlite" if catalog else "lojas.sqlite"))
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    try:
        yield db
    finally:
        db.close()


def initialize():
    for catalog in (False, True):
        with database(catalog) as db:
            db.execute("PRAGMA journal_mode=WAL")
            db.executescript(CATALOG if catalog else SCHEMA)
            if catalog:
                seed = Path(__file__).with_name("catalogo_inicial.json")
                with seed.open(encoding="utf-8-sig") as stream:
                    db.executemany("INSERT OR IGNORE INTO products VALUES (?,?,?,unixepoch())", json.load(stream))
                db.commit()


def field(data, key, maximum=120, optional=False):
    value = data.get(key, "")
    if not isinstance(value, str) or len(value.strip()) > maximum or (not optional and not value.strip()):
        raise ApiError(400, f"Confira o campo {key}.")
    return value.strip()


def email(data, key):
    address = field(data, key, 254).lower()
    if address.count("@") != 1 or "." not in address.split("@")[1] or any(c.isspace() for c in address):
        raise ApiError(400, "Confira o e-mail.")
    return address


def password_hash(password, salt=None):
    salt = salt or secrets.token_hex(16)
    return salt + ":" + hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1).hex()


def uid():
    return secrets.token_hex(16)


def key(token):
    return hashlib.sha256(token.encode()).hexdigest()


def limited(db, name, maximum):
    db.execute("""INSERT INTO limits VALUES (?,unixepoch()/900,1)
      ON CONFLICT(key) DO UPDATE SET hits=CASE WHEN window=excluded.window THEN hits+1 ELSE 1 END,
      window=excluded.window""", (name,))
    hits = db.execute("SELECT hits FROM limits WHERE key=?", (name,)).fetchone()[0]
    db.commit()
    if hits > maximum:
        raise ApiError(429, "Muitas tentativas. Aguarde alguns minutos.")


def issue(db, user):
    token = secrets.token_urlsafe(32)
    db.execute("INSERT INTO sessions VALUES (?,?,unixepoch()+86400)", (key(token), user))
    return {"token": token}


def membership(db, user, store, write=False):
    row = db.execute("""SELECT s.*, m.role FROM stores s JOIN members m ON m.store=s.id
        WHERE m.user=? AND s.id=?""", (user, store)).fetchone()
    if not row or (write and row["role"] == "funcionario"):
        raise ApiError(403, "Você não tem permissão nesta loja.")
    return row


def notify_owner(store, employee):
    host = os.environ.get("STOKIO_SMTP_HOST")
    sender = os.environ.get("STOKIO_EMAIL_FROM")
    if not host or not sender:
        return False
    message = EmailMessage()
    message["Subject"] = "Stokio · solicitação de acesso à loja"
    message["From"], message["To"] = sender, store["contact"]
    message.set_content(f"{employee['name']} ({employee['email']}) pediu acesso a {store['name']}.\n"
                        "Abra o Stokio, entre na loja e revise a solicitação em Equipe.")
    try:
        with smtplib.SMTP(host, int(os.environ.get("STOKIO_SMTP_PORT", "587")), timeout=8) as smtp:
            smtp.starttls(context=ssl.create_default_context())
            if os.environ.get("STOKIO_SMTP_USER"):
                smtp.login(os.environ["STOKIO_SMTP_USER"], os.environ["STOKIO_SMTP_PASSWORD"])
            smtp.send_message(message)
        return True
    except (OSError, smtplib.SMTPException, KeyError):
        return False


def gtin(code):
    if not code.isascii() or not code.isdigit() or len(code) not in (8, 12, 13, 14):
        return False
    return (sum(int(n) * (3 if i % 2 == 0 else 1)
                for i, n in enumerate(reversed(code[:-1]))) + int(code[-1])) % 10 == 0


def catalog(code):
    if not gtin(code):
        raise ApiError(400, "Informe um código GTIN válido.")
    with database(True) as db:
        cached = db.execute("SELECT code,name,category FROM products WHERE code=? AND updated>unixepoch()-2592000",
                            (code,)).fetchone()
        if cached:
            return dict(cached)
    params = urlencode({"fields": "product_name,product_name_pt,brands,categories_tags"})
    try:
        req = Request(f"https://world.openfoodfacts.org/api/v3/product/{code}?{params}",
                      headers={"User-Agent": "Stokio/1.3 (https://github.com/VitorGodoi12/Stokio)"})
        with urlopen(req, timeout=5) as response:
            product = json.load(response).get("product") or {}
    except HTTPError as exc:
        if exc.code == 404:
            raise ApiError(404, "Código sem sugestão no catálogo.") from exc
        raise ApiError(503, "Catálogo temporariamente indisponível.") from exc
    except (OSError, ValueError) as exc:
        raise ApiError(503, "Catálogo temporariamente indisponível.") from exc
    name = product.get("product_name_pt") or product.get("product_name")
    if not name:
        raise ApiError(404, "Código sem sugestão no catálogo.")
    tags = product.get("categories_tags") or []
    categories = {"en:sodas": "Refrigerantes", "en:waters": "Águas", "en:juices": "Sucos",
                  "en:beers": "Cervejas", "en:milks": "Leites", "en:rice": "Arroz",
                  "en:beans": "Feijão", "en:pastas": "Massas", "en:coffees": "Cafés",
                  "en:biscuits": "Biscoitos", "en:chocolates": "Chocolates"}
    category = next((value for tag, value in categories.items() if tag in tags), "Outros")
    name = name.strip()[:120]
    with database(True) as db:
        db.execute("INSERT OR REPLACE INTO products VALUES (?,?,?,unixepoch())", (code, name, category))
        db.commit()
    return {"code": code, "name": name, "category": category}


def action(db, method, parts, data, token, ip):
    if method == "POST" and parts in (["register"], ["login"]):
        limited(db, "auth:" + ip, 35)
        address = email(data, "email")
        password = field(data, "password", 128)
        if parts == ["login"]:
            account = db.execute("SELECT id,password FROM users WHERE email=?", (address,)).fetchone()
            test = account["password"] if account else "0" * 32 + ":" + "0" * 128
            if not secrets.compare_digest(test, password_hash(password, test.split(":")[0])) or not account:
                raise ApiError(401, "E-mail ou senha incorretos.")
            return issue(db, account["id"])
        if len(password) < 10:
            raise ApiError(400, "Use uma senha com pelo menos 10 caracteres.")
        user = uid()
        db.execute("INSERT INTO users VALUES (?,?,?,?,?)",
                   (user, field(data,"name"), address, field(data,"phone",30), password_hash(password)))
        if data.get("owner") is True:
            store = uid()
            db.execute("INSERT INTO stores VALUES (?,?,?,?,?,?)",
                       (store, field(data,"market"), field(data,"address",240,True),
                        address, user, secrets.token_hex(6).upper()))
            db.execute("INSERT INTO members VALUES (?,?,?)", (store,user,"dono"))
        return issue(db,user)

    session = db.execute("""SELECT u.id,u.name,u.email FROM sessions x JOIN users u ON u.id=x.user
                            WHERE x.token=? AND x.expires>unixepoch()""", (key(token),)).fetchone()
    if not session:
        raise ApiError(401, "Entre na sua conta para continuar.")
    user = session["id"]
    if method == "POST" and parts == ["logout"]:
        db.execute("DELETE FROM sessions WHERE token=?", (key(token),))
        return {}
    if method == "GET" and parts == ["stores"]:
        return {"stores": [dict(r) for r in db.execute("""SELECT s.id,s.name,s.address,m.role
                FROM stores s JOIN members m ON s.id=m.store WHERE m.user=? ORDER BY s.name""",(user,))]}
    if method == "POST" and parts == ["join"]:
        limited(db,"join:"+user,15)
        code = field(data,"code",24,True).upper()
        if code:
            store = db.execute("SELECT id FROM stores WHERE invite=?",(code,)).fetchone()
            if not store:
                raise ApiError(404,"Código da loja inválido.")
            db.execute("INSERT OR IGNORE INTO members VALUES (?,?,?)",(store["id"],user,"funcionario"))
            db.execute("DELETE FROM requests WHERE store=? AND user=?",(store["id"],user))
            return {"joined":True}
        store = db.execute("SELECT * FROM stores WHERE contact=?", (email(data,"contact"),)).fetchone()
        if not store:
            raise ApiError(404,"Não foi possível localizar uma loja com esse e-mail.")
        if db.execute("SELECT 1 FROM members WHERE store=? AND user=?",(store["id"],user)).fetchone():
            raise ApiError(409,"Você já faz parte desta loja.")
        db.execute("INSERT OR IGNORE INTO requests(store,user,status) VALUES (?,?,?)",
                           (store["id"],user,"pending"))
        db.commit()
        pedido = db.execute("SELECT status,emailed FROM requests WHERE store=? AND user=?", (store["id"],user)).fetchone()
        if pedido["status"] != "pending":
            raise ApiError(409,"O dono já recusou a solicitação. Entre em contato com a loja.")
        sent = bool(pedido["emailed"]) or notify_owner(store,session)
        if sent:
            db.execute("UPDATE requests SET emailed=1 WHERE store=? AND user=?",(store["id"],user))
        return {"emailed":sent}
    if method == "GET" and len(parts)==2 and parts[0]=="catalog":
        limited(db,"catalog:"+user,100)
        return catalog(parts[1])
    if method == "GET" and parts == ["catalog"]:
        with database(True) as catalog_db:
            return {"products": [dict(r) for r in catalog_db.execute(
                "SELECT code,name,category FROM products ORDER BY name LIMIT 250")]}
    if len(parts)<3 or parts[0]!="stores":
        raise ApiError(404,"Recurso não encontrado.")
    store, resource = parts[1:3]
    m = membership(db,user,store,write=method!="GET" or resource=="team")
    if method=="GET" and resource=="inventory":
        return {"products":[dict(r) for r in db.execute("""SELECT p.*,a.name AS aisle_name
               FROM stock p LEFT JOIN aisles a ON p.aisle=a.id WHERE p.store=? ORDER BY p.category,p.name""",(store,))],
                "aisles":[dict(r) for r in db.execute("""SELECT a.*,u.name AS responsible_name
               FROM aisles a LEFT JOIN users u ON a.responsible=u.id WHERE a.store=? ORDER BY a.name""",(store,))]}
    if method=="GET" and resource=="team":
        return {"invite":m["invite"],"founder":m["founder"],
                "members":[dict(r) for r in db.execute("""SELECT u.id,u.name,u.email,u.phone,m.role
                FROM members m JOIN users u ON m.user=u.id WHERE m.store=?""",(store,))],
                "requests":[dict(r) for r in db.execute("""SELECT u.id,u.name,u.email,u.phone
                FROM requests r JOIN users u ON r.user=u.id WHERE r.store=? AND r.status='pending'""",(store,))]}
    if method=="POST" and resource=="role":
        target=field(data,"user",32)
        role=field(data,"role",15)
        if role not in ("funcionario","gerente","dono","recusar"):
            raise ApiError(400,"Cargo inválido.")
        current=db.execute("SELECT role FROM members WHERE store=? AND user=?",(store,target)).fetchone()
        if target==m["founder"] or (m["role"]!="dono" and (role=="dono" or (current and current["role"]=="dono"))):
            raise ApiError(403,"Somente um dono pode atribuir ou alterar esse cargo.")
        pending=db.execute("SELECT 1 FROM requests WHERE store=? AND user=? AND status='pending'",(store,target)).fetchone()
        if not current and not pending:
            raise ApiError(404,"Convite ou membro não encontrado.")
        if role=="recusar":
            if not pending:
                raise ApiError(400,"Não há solicitação para recusar.")
            db.execute("UPDATE requests SET status='denied' WHERE store=? AND user=?",(store,target))
        else:
            db.execute("""INSERT INTO members VALUES (?,?,?)
                       ON CONFLICT(store,user) DO UPDATE SET role=excluded.role""",(store,target,role))
            db.execute("DELETE FROM requests WHERE store=? AND user=?",(store,target))
        return {}
    if method=="POST" and resource=="aisles":
        name=field(data,"name")
        responsible=field(data,"responsible",32,True) or None
        if responsible:
            membership(db,responsible,store)
        aisle=field(data,"id",32,True)
        if aisle:
            changed=db.execute("UPDATE aisles SET name=?,responsible=? WHERE store=? AND id=?",
                               (name,responsible,store,aisle)).rowcount
            if not changed:
                raise ApiError(404,"Corredor não encontrado.")
        else:
            db.execute("INSERT INTO aisles VALUES (?,?,?,?)",(uid(),store,name,responsible))
        return {}
    if method=="POST" and resource=="import":
        products=data.get("products")
        if not isinstance(products,list) or len(products)>500:
            raise ApiError(400,"Importe até 500 produtos por vez.")
        inserted=0
        for product in products:
            if not isinstance(product,dict):
                raise ApiError(400,"Produto inválido.")
            source=field(product,"source",100)
            mark=db.execute("INSERT OR IGNORE INTO local_imports VALUES (?,?)",(store,source))
            if not mark.rowcount:
                continue
            code=product.get("barcode")
            if code and db.execute("SELECT 1 FROM stock WHERE store=? AND barcode=?",(store,code)).fetchone():
                continue
            action(db,"POST",["stores",store,"products"],{
                field:product.get(field) for field in ("name","category","barcode","quantity","expiration")
            } | {"barcode":code or "", "expiration":product.get("expiration") or ""},token,ip)
            inserted+=1
        return {"inserted":inserted}
    if method=="POST" and resource=="products":
        name,category=field(data,"name"),field(data,"category")
        code=field(data,"barcode",40,True) or None
        expiration=field(data,"expiration",10,True) or None
        if expiration:
            try:
                date.fromisoformat(expiration)
            except ValueError as exc:
                raise ApiError(400,"Use uma data válida no formato AAAA-MM-DD.") from exc
        aisle=field(data,"aisle",32,True) or None
        if aisle and not db.execute("SELECT 1 FROM aisles WHERE store=? AND id=?",(store,aisle)).fetchone():
            raise ApiError(404,"Corredor não encontrado.")
        qty=data.get("quantity")
        if type(qty) is not int or not 0<=qty<=999999999:
            raise ApiError(400,"Confira a quantidade.")
        product=field(data,"id",32,True)
        if product:
            result=db.execute("""UPDATE stock SET name=?,category=?,barcode=?,quantity=?,expiration=?,aisle=?,
                              revision=revision+1 WHERE store=? AND id=? AND revision=?""",
                              (name,category,code,qty,expiration,aisle,store,product,data.get("revision")))
            if not result.rowcount:
                raise ApiError(409,"O produto mudou. Atualize a lista e tente novamente.")
        else:
            db.execute("INSERT INTO stock VALUES (?,?,?,?,?,?,?,?,1)",(uid(),store,name,category,code,qty,expiration,aisle))
        return {}
    raise ApiError(404,"Recurso não encontrado.")


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, value):
        self.send_response(status)
        self.send_header("Content-Type","application/json; charset=utf-8")
        origin=self.headers.get("Origin")
        if origin and origin in os.environ.get("STOKIO_WEB_ORIGINS","").split(","):
            self.send_header("Access-Control-Allow-Origin",origin)
            self.send_header("Vary","Origin")
            self.send_header("Access-Control-Allow-Headers","Authorization, Content-Type")
            self.send_header("Access-Control-Allow-Methods","GET, POST, OPTIONS")
        self.send_header("Cache-Control","no-store")
        self.end_headers()
        self.wfile.write(json.dumps(value,ensure_ascii=False).encode())

    def do_OPTIONS(self):
        self.respond(200,{})

    def handle_api(self):
        parts=urlsplit(self.path).path.strip("/").split("/")
        if parts==["health"]:
            return self.respond(200,{"ok":True})
        try:
            if parts[0]!="api":
                raise ApiError(404,"Recurso não encontrado.")
            length=int(self.headers.get("Content-Length","0"))
            if not 0<=length<=(1048576 if parts[-1]=="import" else 16384):
                raise ApiError(413,"Dados demais na solicitação.")
            data=json.loads(self.rfile.read(length)) if length else {}
            if not isinstance(data,dict):
                raise ApiError(400,"Dados inválidos.")
            token=self.headers.get("Authorization","").removeprefix("Bearer ")
            ip = self.client_address[0]
            if os.environ.get("STOKIO_PROXY_PRIVADO") == "1":
                forwarded = self.headers.get("X-Stokio-Client-IP")
                if forwarded:
                    ip = str(ipaddress.ip_address(forwarded))
            with database() as db:
                try:
                    result=action(db,self.command,parts[1:],data,token,ip)
                    db.commit()
                except Exception:
                    db.rollback()
                    raise
            self.respond(200,result)
        except ApiError as exc:
            self.respond(exc.status,{"error":exc.message})
        except sqlite3.IntegrityError:
            self.respond(409,{"error":"Já existe um registro com esses dados."})
        except (ValueError,TypeError):
            self.respond(400,{"error":"Dados inválidos."})

    do_GET=handle_api
    do_POST=handle_api


if __name__=="__main__":
    initialize()
    # Em produção, mantenha a porta privada atrás de um proxy HTTPS.
    ThreadingHTTPServer((os.environ.get("STOKIO_HOST","127.0.0.1"),
                         int(os.environ.get("STOKIO_PORT","8765"))),Handler).serve_forever()
