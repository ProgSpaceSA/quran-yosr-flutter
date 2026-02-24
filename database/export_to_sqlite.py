# -*- coding: utf-8 -*-
import mysql.connector
import sqlite3
import os

SQLITE_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'database', 'quran.db')
os.makedirs(os.path.dirname(SQLITE_PATH), exist_ok=True)

# Connect to MySQL — use_unicode=True ensures text columns come back as str
mysql_conn = mysql.connector.connect(
    host='localhost', user='root', password='root', database='quran',
    charset='utf8mb4', use_unicode=True
)
cursor = mysql_conn.cursor()

# Connect to SQLite
if os.path.exists(SQLITE_PATH):
    os.remove(SQLITE_PATH)
sqlite_conn = sqlite3.connect(SQLITE_PATH)
sqlite_cursor = sqlite_conn.cursor()

# Create table
sqlite_cursor.execute('''
CREATE TABLE quran_ayahs (
    id INTEGER PRIMARY KEY,
    jozz INTEGER NOT NULL,
    sura_no INTEGER NOT NULL,
    aya_no INTEGER NOT NULL,
    sura_name_en TEXT NOT NULL,
    sura_name_ar TEXT NOT NULL,
    page INTEGER NOT NULL,
    line_start INTEGER NOT NULL,
    line_end INTEGER NOT NULL,
    aya_text TEXT NOT NULL,
    aya_text_emlaey TEXT NOT NULL
)
''')
sqlite_cursor.execute('CREATE INDEX idx_surah ON quran_ayahs (sura_no)')
sqlite_cursor.execute('CREATE INDEX idx_surah_ayah ON quran_ayahs (sura_no, aya_no)')
sqlite_cursor.execute('CREATE INDEX idx_page ON quran_ayahs (page)')

# Fetch all rows; decode any bytes columns (e.g. utf8mb4_bin) to str
cursor.execute('SELECT id, jozz, sura_no, aya_no, sura_name_en, sura_name_ar, page, line_start, line_end, aya_text, aya_text_emlaey FROM quran_ayahs ORDER BY id')
raw_rows = cursor.fetchall()

def to_str(v):
    return v.decode('utf-8') if isinstance(v, (bytes, bytearray)) else v

rows = [tuple(to_str(col) for col in row) for row in raw_rows]
sqlite_cursor.executemany('INSERT INTO quran_ayahs VALUES (?,?,?,?,?,?,?,?,?,?,?)', rows)

sqlite_conn.commit()
mysql_conn.close()
sqlite_conn.close()

print(f"Exported {len(rows)} ayahs to {os.path.abspath(SQLITE_PATH)}")
