# MySQL Import and Validation

Phase 5 is complete: the RetailPulse MySQL data layer was cleanly reloaded and the reported validation checks passed. This record uses the confirmed results supplied for that run; this Codex session did not connect to MySQL or independently rerun the import.

## Import correction

The previous import was short by 20 source rows. Its `LOAD DATA` statements configured the double quote as both the enclosure and generic escape character. The corrected script uses `ESCAPED BY ''`, allowing doubled enclosure quotes (for example, `""`) to be read as standard CSV quote syntax without also treating every quote as a generic escape. MySQL 8 documents doubled enclosure characters as valid input. This correction does not clean or transform source data.

After the corrected configuration and a clean reload, the source-to-database row-count discrepancies were resolved: all eight tables matched their expected counts. This confirms the issue was resolved for this reload and is consistent with the quote-handling correction. There was no isolated before/after experiment proving that this setting alone caused every skipped row. The load script preserves LF terminators for the seven LF files and CRLF terminators for reviews and category translations, existing `NULLIF` handling, and parent-before-child table order.

## Safe clean reload (manual)

Run these commands in PowerShell from the RetailPulse project root. Each command prompts locally for the MySQL password; never put the password in the command or a project file. The reset command **permanently deletes the existing `retailpulse` database and its data**. Run it only when you intend to discard that database and rebuild it.

```powershell
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/00_reset_database.sql"
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/01_create_database.sql"
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/02_create_tables.sql"
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/03_load_data.sql"
mysql --protocol=TCP --host=127.0.0.1 --user=root --password --local-infile=1 --execute="source sql/04_validation_checks.sql"
```

The `03_load_data.sql` script issues `SHOW WARNINGS;` immediately after each of its eight `LOAD DATA` statements. Review each warning result and the mysql client's `Records`/`Skipped`/`Warnings` summary before accepting the import. The script continues through its statements so all diagnostics may be printed; if any load reports a warning, skipped row, or unexpected count, treat the import as unsuccessful and investigate before using the data. For a fresh retry after a partial load, intentionally run the reset and all five steps again.

If the `LOAD DATA` summary reports more warnings than `SHOW WARNINGS` displays, stop and investigate the warning total and the first displayed warnings. Do not change MySQL server settings or suppress warnings to force the import through.

## Confirmed row-count validation

`sql/04_validation_checks.sql` reports expected count, actual count, difference, and `PASS`/`CHECK`. All reported tables matched:

| Table | Expected rows | Actual rows | Difference | Status |
|---|---:|---:|---:|---|
| customers | 99,441 | 99,441 | 0 | PASS |
| orders | 99,441 | 99,441 | 0 | PASS |
| order_items | 112,650 | 112,650 | 0 | PASS |
| payments | 103,886 | 103,886 | 0 | PASS |
| reviews | 99,224 | 99,224 | 0 | PASS |
| products | 32,951 | 32,951 | 0 | PASS |
| sellers | 3,095 | 3,095 | 0 | PASS |
| product_category_translations | 71 | 71 | 0 | PASS |

## Other confirmed technical checks

- All tested foreign-key/orphan relationships returned `0` orphan rows.
- Zero or negative prices: `0`.
- Zero freight rows: `383`.
- Negative freight rows: `0`.
- Products without a category: `610`.
- Distinct `customer_unique_id` values: `96,096`.

These are technical data-quality results. The zero-freight rows and products without a category are reported as present values, not silently changed or treated here as business findings.

The same validation script retains primary/composite-key duplicate checks, foreign-key orphan checks, required-field checks, and basic numeric/status/category checks. The results above do not mean business analysis is complete; no business KPIs or conclusions are reported here.

## If warnings or counts are wrong

Do not accept the load or begin analysis. Save the mysql output locally, including the `LOAD DATA` summary and its immediately following `SHOW WARNINGS` output. Identify the affected source file and row from the warning, check the corresponding schema and source record, then correct the import definition only when the warning supports that change. Do not manually insert only the missing rows as the repair. After deciding on a correction, repeat the documented clean reset and full import so the result remains reproducible. Never edit the raw CSV files as part of this process.
