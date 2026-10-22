# MySQL Import Validation

## Current status: blocked before database access

The database and tables have **not** been created, and no CSV has been imported. MySQL reports version 8.0.46 and the `MySQL80` service is running. The read-only connection check failed with:

```text
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)
```

RetailPulse has no `.env` file and no `MYSQL*`, `DB_*`, or `RETAILPULSE*` environment variables were present. Credentials were not requested in chat, printed, or written into project files. No database operation was attempted after the authentication failure.

## Planned database and tables

- Database: `retailpulse`
- Tables: `customers`, `products`, `sellers`, `product_category_translations`, `orders`, `order_items`, `payments`, and `reviews`.
- Raw geolocation is excluded from the initial core schema as specified in `MYSQL_SCHEMA_DESIGN.md`.

## Source and database row counts

Database counts and differences are **not available** because no import occurred. Expected counts below come from the Phase 3 raw-file audit.

| Table | Expected source rows | Database rows | Difference |
|---|---:|---:|---:|
| customers | 99,441 | Not imported | Not calculated |
| orders | 99,441 | Not imported | Not calculated |
| order_items | 112,650 | Not imported | Not calculated |
| payments | 103,886 | Not imported | Not calculated |
| reviews | 99,224 | Not imported | Not calculated |
| products | 32,951 | Not imported | Not calculated |
| sellers | 3,095 | Not imported | Not calculated |
| product_category_translations | 71 | Not imported | Not calculated |

## Validation results

- Primary-key and composite-key constraints: designed in `sql/02_create_tables.sql`; not applied or verified in MySQL.
- Foreign keys and orphan checks: specified in the table script and `sql/04_validation_checks.sql`; not applied or run.
- Null, numeric, status, category, and customer identifier checks: queries are prepared in `sql/04_validation_checks.sql`; not run against MySQL.
- Import method: prepared `LOAD DATA LOCAL INFILE` script; not run.

## Issue and safe resolution

The blocker is missing local MySQL authentication, not a verified database/schema error. Set up a local MySQL login that has permission to create the `retailpulse` database and its tables, then use the interactive `mysql -p` password prompt. Do not put a password in SQL scripts or paste it into chat. If the account is not `root`, substitute the permitted local username in the commands. If `LOCAL INFILE` is later refused, stop and inspect the server's current configuration and error message; do not change server settings automatically or enable global file loading as a workaround.

From PowerShell opened in the RetailPulse project root, authenticate interactively and run the scripts one at a time after confirming the account:

```powershell
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/01_create_database.sql"
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/02_create_tables.sql"
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/03_load_data.sql"
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/04_validation_checks.sql"
```

Each command prompts locally for the password; do not add the password after `--password` or save it in the command history. If the local account is not `root`, change only the username to the authorized account.

After access is configured, run the scripts from the RetailPulse project root in order and record actual counts/check results here. The import script is intended for empty tables and should not be rerun after a partial load until the table state has been inspected. No cleanup or destructive recovery was performed.

## Limitations

This document records preparation and the access failure only; it is not evidence of successful setup. Raw CSVs remain unchanged and excluded from Git by `.gitignore`. No credentials are documented here. No business analysis has started.
