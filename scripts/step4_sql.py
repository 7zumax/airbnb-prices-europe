"""Step 4 runner: imports airbnb_cleaned.xlsx into SQL Server and runs step4_normalize.sql."""
import os, re, sys, urllib.parse
import pandas as pd
import pyodbc
from sqlalchemy import create_engine
from sqlalchemy.types import NVARCHAR

here = os.path.dirname(os.path.abspath(__file__))
DB = "AirbnbEurope"

# 1. Pick a SQL Server ODBC driver
drivers = [d for d in pyodbc.drivers() if "SQL Server" in d]
print("Drivers:", drivers)
modern = sorted(d for d in drivers if d.startswith("ODBC Driver"))
driver = (modern or drivers)[-1]
print("Using driver:", driver)

def conn_str(server, db):
    return (f"DRIVER={{{driver}}};SERVER={server};DATABASE={db};"
            "Trusted_Connection=yes;TrustServerCertificate=yes;")

# 2. Find the local SQL Server instance
pc = os.environ.get("COMPUTERNAME", "localhost")
candidates = ["localhost", r"localhost\SQLEXPRESS", pc, pc + r"\SQLEXPRESS", r"(localdb)\MSSQLLocalDB"]
server = None
for s in candidates:
    try:
        pyodbc.connect(conn_str(s, "master"), timeout=5, autocommit=True).close()
        server = s
        break
    except Exception as e:
        print("Not reachable:", s, "|", str(e)[:150])
if server is None:
    sys.exit("No SQL Server instance found")
print("Server name:", server)

# 3. Create the database
with pyodbc.connect(conn_str(server, "master"), autocommit=True) as c:
    c.execute(f"IF DB_ID('{DB}') IS NULL CREATE DATABASE {DB};")
print("Database ready:", DB)

# 4. Import the cleaned Excel into a staging table
clean = pd.read_excel(os.path.join(here, "airbnb_cleaned.xlsx"),
                      dtype={"neighbourhood": str, "property_type": str})
print("Excel loaded:", clean.shape)
engine = create_engine("mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(conn_str(server, DB)),
                       fast_executemany=True)
text_cols = ["room_type", "city", "day_type", "property_type", "neighbourhood"]
clean.to_sql("airbnb_staging", engine, if_exists="replace", index=False,
             dtype={col: NVARCHAR(200) for col in text_cols}, chunksize=1000)
print("Staging table uploaded")

# 5. Run the normalization script batch by batch (split on GO)
sql = open(os.path.join(here, "step4_normalize.sql"), encoding="utf-8").read()
batches = [b for b in re.split(r"^\s*GO\s*$", sql, flags=re.MULTILINE | re.IGNORECASE) if b.strip()]
with pyodbc.connect(conn_str(server, DB), autocommit=True) as c:
    cur = c.cursor()
    for b in batches:
        cur.execute(b)
        while True:
            if cur.description:
                cols = [d[0] for d in cur.description]
                print(pd.DataFrame.from_records(cur.fetchall(), columns=cols).to_string(index=False))
            if not cur.nextset():
                break
    n = cur.execute("SELECT COUNT(*) FROM Listings").fetchone()[0]
    for t in ["Cities", "DayTypes", "RoomTypes", "PropertyTypes", "Neighbourhoods", "Listings"]:
        print(t, cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0])
    if n == len(clean):
        cur.execute("DROP TABLE airbnb_staging;")
        print("Row counts match -> staging table dropped")
print("STEP 4 DONE")
