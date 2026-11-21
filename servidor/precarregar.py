import sys
from stokio import ApiError, catalog, initialize

initialize()
if len(sys.argv) < 2:
    raise SystemExit("Informe os GTINs conferidos nas embalagens, separados por espaço.")
for code in sys.argv[1:]:
    try:
        record = catalog(code)
        print(f"{code}: {record['name']} ({record['category']})")
    except ApiError as error:
        print(f"{code}: {error.message}")
