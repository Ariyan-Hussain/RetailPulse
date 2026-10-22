"""Read-only source-to-MySQL key diagnostic for the RetailPulse Phase 5 import.

Run from the RetailPulse root with: python .\python\diagnose_import.py
The mysql client prompts locally for the password. This script writes no files
and performs no database changes.
"""

from __future__ import annotations

import csv
import json
import shutil
import subprocess
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"

SOURCES = {
    "customers": ("olist_customers_dataset.csv", ("customer_id",)),
    "products": ("olist_products_dataset.csv", ("product_id",)),
    "sellers": ("olist_sellers_dataset.csv", ("seller_id",)),
    "orders": ("olist_orders_dataset.csv", ("order_id",)),
    "order_items": ("olist_order_items_dataset.csv", ("order_id", "order_item_id")),
    "payments": ("olist_order_payments_dataset.csv", ("order_id", "payment_sequential")),
    "reviews": ("olist_order_reviews_dataset.csv", ("review_id", "order_id")),
}

PARENTS = {
    "orders": {"customer_id": "customers"},
    "order_items": {
        "order_id": "orders",
        "product_id": "products",
        "seller_id": "sellers",
    },
    "payments": {"order_id": "orders"},
    "reviews": {"order_id": "orders"},
}


def run_mysql(user: str, query: str) -> list[str]:
    """Run a query with the installed mysql client; password is prompted, not stored."""
    if not shutil.which("mysql"):
        raise RuntimeError("mysql.exe was not found on PATH.")
    command = [
        "mysql", "--protocol=TCP", "--host=127.0.0.1", f"--user={user}",
        "--password", "--database=retailpulse", "--batch", "--raw",
        "--skip-column-names", f"--execute={query}",
    ]
    result = subprocess.run(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=None,  # Keeps the MySQL password prompt visible in this console.
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode:
        raise RuntimeError(f"mysql exited with code {result.returncode}; see its error above.")
    return result.stdout.splitlines()


def database_keys(user: str) -> dict[str, set[tuple[str, ...]]]:
    selects = [
        "SELECT 'customers', customer_id, '' FROM customers",
        "SELECT 'products', product_id, '' FROM products",
        "SELECT 'sellers', seller_id, '' FROM sellers",
        "SELECT 'orders', order_id, '' FROM orders",
        "SELECT 'order_items', order_id, CAST(order_item_id AS CHAR) FROM order_items",
        "SELECT 'payments', order_id, CAST(payment_sequential AS CHAR) FROM payments",
        "SELECT 'reviews', review_id, order_id FROM reviews",
    ]
    found: dict[str, set[tuple[str, ...]]] = defaultdict(set)
    for line in run_mysql(user, " UNION ALL ".join(selects)):
        fields = line.split("\t", 2)
        if len(fields) != 3:
            raise RuntimeError("Unexpected key-query output; no comparison was performed.")
        table, key1, key2 = fields
        found[table].add((key1,) if key2 == "" else (key1, key2))
    return found


def row_risks(row: dict[str | None, object], expected_columns: list[str]) -> dict[str, object]:
    extra_values = row.get(None)
    return {
        "blank_fields": [name for name in expected_columns if row.get(name) in (None, "")],
        "missing_columns": [name for name in expected_columns if row.get(name) is None],
        "extra_csv_values": extra_values if extra_values else [],
        "fields_with_commas": [name for name in expected_columns if "," in (row.get(name) or "")],
        "fields_with_quotes": [name for name in expected_columns if '"' in (row.get(name) or "")],
        "fields_with_embedded_newlines": [
            name for name in expected_columns if "\n" in (row.get(name) or "") or "\r" in (row.get(name) or "")
        ],
    }


def source_line_endings(path: Path) -> dict[str, int]:
    data = path.read_bytes()
    crlf = data.count(b"\r\n")
    return {"CRLF": crlf, "LF_only": data.count(b"\n") - crlf}


def source_missing_rows(
    table: str, filename: str, key_columns: tuple[str, ...], db_keys: set[tuple[str, ...]]
) -> tuple[int, list[dict[str, object]], dict[str, int]]:
    path = RAW / filename
    by_key: dict[tuple[str, ...], list[dict[str, str | None]]] = defaultdict(list)
    counts: Counter[tuple[str, ...]] = Counter()
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames:
            raise RuntimeError(f"No CSV header found in {filename}.")
        for row in reader:
            key = tuple(row.get(column) or "" for column in key_columns)
            counts[key] += 1
            by_key[key].append(row)

    missing: list[dict[str, object]] = []
    parent_columns = PARENTS.get(table, {})
    for key, rows in by_key.items():
        if key in db_keys:
            continue
        for row in rows:
            parent_checks = {
                column: {
                    "parent_table": parent_table,
                    "exists_in_mysql": ((row.get(column) or ""),) in db_keys_by_table.get(parent_table, set()),
                }
                for column, parent_table in parent_columns.items()
            }
            missing.append({
                "table": table,
                "key": key[0] if len(key) == 1 else key,
                "full_source_row": row,
                "parent_foreign_keys": parent_checks or "not applicable",
                "source_key_occurrences": counts[key],
                "source_key_duplicated": counts[key] > 1,
                "csv_parse_risks": row_risks(row, list(row.keys()) if None not in row else [k for k in row if k is not None]),
                "import_reason": "Not proven by key comparison alone; correlate with retained LOAD DATA warnings below.",
            })
    return len(counts), missing, source_line_endings(path)


def retained_load_warnings(user: str) -> list[str]:
    # Performance Schema may be disabled or permission-restricted. A missing
    # history row does not prove the old LOAD DATA statement had no warnings.
    query = (
        "SELECT COALESCE(LEFT(REPLACE(SQL_TEXT, CHAR(10), ' '), 240), ''), "
        "ERRORS, WARNINGS, ROWS_AFFECTED "
        "FROM performance_schema.events_statements_history_long "
        "WHERE SQL_TEXT LIKE 'LOAD DATA LOCAL INFILE%' "
        "ORDER BY TIMER_END DESC LIMIT 30"
    )
    try:
        return run_mysql(user, query)
    except RuntimeError as exc:
        return [f"Performance Schema history unavailable: {exc}"]


if __name__ == "__main__":
    if not RAW.is_dir():
        raise SystemExit(f"Run this script from the existing RetailPulse project; not found: {RAW}")
    mysql_user = input("MySQL username [root]: ").strip() or "root"
    try:
        # One set-based export avoids a database query for each source row.
        db_keys_by_table = database_keys(mysql_user)
        print("\nRetained LOAD DATA statement history (if Performance Schema kept it):")
        for warning_row in retained_load_warnings(mysql_user):
            print(warning_row)
        print("\nMissing source keys and full rows:")
        total = 0
        for table, (filename, key_columns) in SOURCES.items():
            distinct_source_keys, missing, endings = source_missing_rows(
                table, filename, key_columns, db_keys_by_table.get(table, set())
            )
            total += len(missing)
            print(json.dumps({
                "table_summary": table,
                "distinct_source_keys": distinct_source_keys,
                "database_keys": len(db_keys_by_table.get(table, set())),
                "missing_source_rows": len(missing),
                "source_line_endings": endings,
            }, ensure_ascii=False))
            for item in missing:
                print(json.dumps(item, ensure_ascii=False))
        print(f"\nTotal source rows missing from MySQL by the requested keys: {total}")
        print("No database tables or source files were modified by this script.")
    except (OSError, RuntimeError, csv.Error) as exc:
        raise SystemExit(f"Diagnostic stopped without changing the database: {exc}")
