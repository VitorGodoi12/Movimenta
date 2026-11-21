import json
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from unittest.mock import patch

import stokio


class ApiTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        previous = stokio.DATA
        stokio.DATA = Path(directory.name)
        self.addCleanup(setattr, stokio, "DATA", previous)
        stokio.initialize()
        server = ThreadingHTTPServer(("127.0.0.1", 0), stokio.Handler)
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{server.server_port}/api/"

    def api(self, path, data=None, token="", expect=200):
        request = Request(self.base + path, data=None if data is None else json.dumps(data).encode(),
                          headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
        try:
            result = urlopen(request, timeout=6)
        except HTTPError as error:
            result = error
        with result:
            self.assertEqual(result.code, expect)
            return json.load(result)

    def register(self, name, owner=False):
        contact = name.lower() + "@example.org"
        token = self.api("register", {"name":name,"email":contact,"phone":"11999999999",
                                      "password":"uma senha de teste","owner":owner,"market":name})["token"]
        return token, contact

    def test_roles_requests_store_isolation_and_inventory(self):
        owner, contact = self.register("Mercado", True)
        stranger, _ = self.register("Vizinho", True)
        worker, _ = self.register("Funcionaria")
        assistant, _ = self.register("Ajudante")
        store = self.api("stores",token=owner)["stores"][0]["id"]
        route = "stores/" + store
        self.api(route+"/inventory",token=stranger,expect=403)
        with patch.object(stokio, "notify_owner", return_value=True) as mail:
            self.assertTrue(self.api("join",{"contact":contact},worker)["emailed"])
            mail.assert_called_once()
        team = self.api(route+"/team",token=owner)
        invite = team["invite"]
        person = team["requests"][0]["id"]
        self.api("join",{"code":invite},assistant)
        self.api(route+"/team",token=assistant,expect=403)
        self.api(route+"/products",{"name":"Produto"},assistant,expect=403)
        self.api(route+"/role",{"user":person,"role":"gerente"},owner)
        self.api(route+"/role",{"user":team["founder"],"role":"funcionario"},worker,expect=403)
        self.api(route+"/aisles",{"name":"Corredor 3","responsible":person},worker)
        aisle=self.api(route+"/inventory",token=assistant)["aisles"][0]["id"]
        product={"name":"Refrigerante","category":"Refrigerantes","barcode":"5901234123457",
                 "quantity":5,"expiration":"2030-12-31","aisle":aisle}
        self.api(route+"/products",product,worker)
        saved=self.api(route+"/inventory",token=assistant)["products"][0]
        self.assertEqual(saved["quantity"],5)
        self.assertEqual(saved["expiration"],"2030-12-31")
        self.assertEqual(saved["aisle_name"],"Corredor 3")
        product.update(id=saved["id"],revision=saved["revision"],quantity=9)
        self.api(route+"/products",product,worker)
        self.api(route+"/products",product,worker,expect=409)
        copy = {"products":[{"source":"local-1","name":"Agua","category":"Aguas",
                            "quantity":8,"barcode":"","expiration":""}]}
        self.assertEqual(self.api(route+"/import",copy,owner)["inserted"],1)
        self.assertEqual(self.api(route+"/import",copy,owner)["inserted"],0)
        self.assertEqual(len(self.api("catalog",token=owner)["products"]),15)
        self.api("logout",{},assistant)
        self.api("stores",token=assistant,expect=401)

    def test_catalog_cache_and_gtin(self):
        owner, _ = self.register("Mercado", True)
        with stokio.database(True) as db:
            db.execute("INSERT INTO products VALUES (?,?,?,unixepoch())",
                       ("5901234123457","Produto de teste","Mercearia"))
            db.commit()
        self.assertEqual(self.api("catalog/5901234123457",token=owner)["name"],"Produto de teste")
        self.api("catalog/5901234123458",token=owner,expect=400)


if __name__ == "__main__":
    unittest.main()
