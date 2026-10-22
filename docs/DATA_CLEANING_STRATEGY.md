# Data Cleaning Strategy

## Purpose and boundaries

This document plans future preparation; it does not clean the files. The nine source CSVs under `data/raw/` are the immutable raw layer. Never overwrite, rename, or “fix” those files. Future cleaned outputs belong under `data/cleaned/`, with reproducible rules and source-to-output validation. No cleaned files are created in this phase.

For every field, preserve the raw value alongside any normalized value when normalization could change meaning. Record row counts before and after each transformation. Quarantine or report unexpected values rather than silently dropping or coercing them.

## Missingness and duplicate vocabulary

- **Expected:** absent because the source event/state does not call for a value (for example, a delivery timestamp for an order that has not been delivered).
- **Optional:** a legitimate optional attribute (for example, review comment text).
- **Analytically important:** a missing value that limits a specific measure or join (for example, product category).
- **Potentially invalid:** a missing value in a field expected to identify or describe a record (for example, an order ID). Investigate and report; do not automatically invent a replacement.
- **Exact duplicate row:** every source field is identical. Confirm at the full-row grain before removing it from a derived output.
- **Repeated business key:** a key such as `order_id` occurs on multiple valid item/payment/review rows. This is not, by itself, a duplicate.

Blank CSV fields may be represented as SQL `NULL` in the clean layer, but only after distinguishing blanks from meaningful source strings such as `not_defined`. Do not fill values with zero, “Unknown,” averages, or guessed labels in the source-cleaning step.

## Per-file plan

### `olist_customers_dataset.csv` — customers

- **Preserve:** all source rows and all five fields; retain both `customer_id` and `customer_unique_id`.
- **Clean / standardize:** trim accidental surrounding whitespace only into separate normalized fields if detected; uppercase state codes only after checking source values. Preserve original city text and postal prefix.
- **Do not change:** do not merge customer rows by `customer_unique_id`, and do not treat `customer_id` as the repeat-customer identity. Keep postal codes as strings so leading zeroes are not lost.
- **Analytical exclusions:** no row exclusion is planned. If an identifier is missing or cannot join, flag/quarantine it for review rather than silently dropping it.
- **Types:** IDs `VARCHAR(32)`; postal prefix `CHAR(5)`; city `VARCHAR` sized after max-length validation; state `CHAR(2)`.
- **Nulls / deduplication:** the audit found no blanks or full-row duplicates. Require `customer_id`; retain repeated `customer_unique_id` values as valid. Do not deduplicate on the latter.
- **Risk:** grouping by `customer_id` undercounts returning customers; merging rows by `customer_unique_id` discards order-level address observations.

### `olist_orders_dataset.csv` — orders

- **Preserve:** every `order_id`, source `order_status`, and lifecycle timestamp, including canceled and unavailable records.
- **Clean / standardize:** parse timestamps consistently as `DATETIME` after validating source format; trim status whitespace and normalize case only in a derived column, while retaining the raw status. Validate status against the eight observed labels and flag any new label.
- **Do not change:** do not infer missing lifecycle dates, replace statuses, or interpret this file as an order-status history table; it is a snapshot with one status per order.
- **Analytical exclusions:** status-based rules are defined below and apply only to a specific analysis, never to the stored dataset.
- **Types:** IDs `VARCHAR(32)`; status `VARCHAR(20)` or a carefully validated constrained code; timestamps `DATETIME` nullable for lifecycle milestones.
- **Nulls / deduplication:** purchase and estimated-delivery timestamps were populated; approval/carrier/delivery timestamps have audited missingness. Preserve those as `NULL`. `order_id` is unique in the inspected source; duplicates or blank IDs should fail validation, not be arbitrarily collapsed.
- **Risk:** timezone-naive source values must not be shifted or assigned an assumed zone without an explicit project rule. Missing dates can be valid for incomplete/non-delivered states.

### `olist_order_items_dataset.csv` — order items

- **Preserve:** every line and its `(order_id, order_item_id)` pair; keep `price` and `freight_value` as separate measures.
- **Clean / standardize:** parse `shipping_limit_date`; convert `price` and `freight_value` using exact decimal arithmetic. Validate nonnegative values and the composite key. Keep zero freight flagged for review.
- **Do not change:** do not remove repeated order IDs, product IDs, or seller IDs; these are expected in line-item grain. Do not convert freight into seller cost or profit.
- **Analytical exclusions:** include/exclude entire orders only through a documented status policy; do not remove individual item lines just because price/freight is zero.
- **Types:** IDs `VARCHAR(32)`; item sequence `SMALLINT UNSIGNED`; date `DATETIME`; monetary fields `DECIMAL(12,2)` after confirming source scale.
- **Nulls / deduplication:** no blanks or full-row duplicates were found. `(order_id, order_item_id)` was unique; preserve all lines. A repeated composite key in future input must be investigated.
- **Risk:** rounding to binary floating point can change currency values; deleting repeated `order_id` rows destroys item-level sales detail.

### `olist_order_payments_dataset.csv` — payments

- **Preserve:** each `(order_id, payment_sequential)` payment record and the source payment type.
- **Clean / standardize:** sequence and installment counts become integers; payment values become `DECIMAL(12,2)`; normalize payment labels only in a separate field after defining a mapping. Keep `not_defined` as its original meaning.
- **Do not change:** do not collapse payments to one row per order during cleaning; do not replace zero payment values or installment counts without source evidence.
- **Analytical exclusions:** use only orders allowed by the relevant analysis policy, and aggregate payments to order grain before joining to line-item measures.
- **Types:** `order_id VARCHAR(32)`, sequence/installments `SMALLINT UNSIGNED`, type `VARCHAR(30)`, value `DECIMAL(12,2)`.
- **Nulls / deduplication:** the audit found no blanks or full-row duplicates. `(order_id, payment_sequential)` was unique; repeated `order_id` values are valid. Flag zero values for interpretation.
- **Risk:** joining payment rows directly to multiple item rows multiplies amounts. Payment value is not automatically identical to recognized item revenue.

### `olist_order_reviews_dataset.csv` — reviews

- **Preserve:** all review rows, IDs, scores, comments, and review timestamps. Keep optional comment text exactly as supplied in the raw layer.
- **Clean / standardize:** parse review dates; trim only outside whitespace in a derived representation if needed. Validate score range 1–5; preserve the original score value for audit.
- **Do not change:** do not deduplicate by `review_id` or `order_id`; do not merge review text or select an arbitrary “latest” review. The observed pair `(review_id, order_id)` is unique but should be revalidated before using it as a clean-table key.
- **Analytical exclusions:** no review row is excluded by default. Analyses may require a valid order key and score; report excluded counts if so.
- **Types:** IDs `VARCHAR(32)`; score `TINYINT UNSIGNED`; comments `TEXT`; timestamps `DATETIME`.
- **Nulls / deduplication:** blank title/message fields are optional and should become `NULL`, not a placeholder. No full-row duplicates were found; 814 repeated review IDs and 551 repeated order IDs require grain-aware handling.
- **Risk:** removing repeated IDs may lose legitimate review records; free text may contain non-ASCII or multiline content and should use `utf8mb4`.

### `olist_products_dataset.csv` — products

- **Preserve:** product identifiers, original Portuguese category names, and all product attributes. Preserve original header spelling in the raw file.
- **Clean / standardize:** convert dimension/count fields to nullable integers; validate nonnegative values. Keep category normalization and English translation as separate fields. A missing translation falls back to the unchanged Portuguese label for display, not an invented translation.
- **Do not change:** do not fabricate category, product name, cost, or profit. Do not convert missing metadata to zero.
- **Analytical exclusions:** products with missing categories may be excluded only from a category-specific view and must be counted separately; do not remove them from order-item totals.
- **Types:** ID `VARCHAR(32)`; category `VARCHAR(100)` after length validation; metadata and dimensions `INT UNSIGNED` nullable.
- **Nulls / deduplication:** 610 category/name-length/description-length/photo-count nulls and two nulls in weight and each dimension were found. Keep missing attributes null. `product_id` is unique; no full-row duplicates.
- **Risk:** zero dimensions/weight and missing category may have distinct meanings; conflating them with missing values distorts shipping or category analysis. Keep the source column name mapping documented (`product_name_lenght` is misspelled in the source).

### `olist_sellers_dataset.csv` — sellers

- **Preserve:** each seller, source city/state, and postal prefix.
- **Clean / standardize:** treat postal prefix as a five-character code; standardize state code only after validation; preserve city spelling in raw and normalized columns separately.
- **Do not change:** do not overwrite seller location with geolocation-derived values; do not infer a cost field.
- **Analytical exclusions:** no seller rows excluded by default. Flag unmatched or conflicting postal mappings in geography-specific use.
- **Types:** ID `VARCHAR(32)`; postal prefix `CHAR(5)`; city `VARCHAR` sized after max-length validation; state `CHAR(2)`.
- **Nulls / deduplication:** no blanks or exact duplicates found; `seller_id` unique. Investigate any future duplicate seller IDs.
- **Risk:** 7 seller postal prefixes did not appear in geolocation, and 35 seller state values did not occur among geolocation states for the same prefix. Do not silently “correct” either side.

### `olist_geolocation_dataset.csv` — geolocation observations

- **Preserve:** raw observations and every original coordinate/text value. Keep the raw file outside the transactional fact joins.
- **Clean / standardize:** validate latitude/longitude ranges and postal-prefix format; identify exact full-row duplicates; profile prefix-to-state/city conflicts. Any later aggregate must be a separate, versioned output with method and conflict flags.
- **Do not change:** do not deduplicate merely on postal prefix, keep an arbitrary coordinate, or join raw observations directly to every order/customer/item row.
- **Analytical exclusions:** omit from core metrics until a safe one-row-per-prefix lookup is approved. Exclude ambiguous prefixes from precise point mapping, while retaining their source rows for review.
- **Types:** prefix `CHAR(5)`; latitude/longitude `DECIMAL(10,7)` (or validated precision appropriate to source); city `VARCHAR` sized after length check; state `CHAR(2)`.
- **Nulls / deduplication:** audit found 261,831 exact repeated full rows and no blank fields. Exact-row deduplication may be appropriate in a future derived geolocation layer after count reconciliation; repeated prefix values are not duplicates by themselves.
- **Risk:** multiple coordinates per prefix and 8 prefixes with multiple state values mean “one point per prefix” requires a declared aggregation. An accidental join can greatly multiply transactional rows.

### `product_category_name_translation.csv` — category translations

- **Preserve:** both original category labels and their supplied English translations.
- **Clean / standardize:** trim category-key whitespace in a derived key only after checking for collisions. Validate that source keys remain unique.
- **Do not change:** do not invent translations for `pc_gamer` or `portateis_cozinha_e_preparadores_de_alimentos`; keep the original source-language category when no translation exists.
- **Analytical exclusions:** do not exclude products solely because a translation is unavailable; category-specific outputs can show the original label or a documented untranslated flag.
- **Types:** both labels `VARCHAR(100)` after length validation; source category name is the primary key in this lookup.
- **Nulls / deduplication:** no blanks or duplicate source labels were found. If future duplicates occur, resolve mapping conflicts before loading; do not choose one arbitrarily.
- **Risk:** an inner join to this file drops products in the two untranslated categories. Use a left join and preserve the original category.

## Analytical Inclusion Rules

These are proposed analysis filters, not data-cleaning deletions. Keep all source orders and statuses in the cleaned order table.

| Status group | Observed statuses | Revenue analysis | Repeat-purchase analysis | Operational analysis |
|---|---|---|---|---|
| Completed | `delivered` | Primary conservative inclusion for completed-order item-price reporting. Label the measure precisely; freight is separate and profitability is unsupported. | Primary candidate status for completed repeat purchases, counted by distinct `order_id` per `customer_unique_id`. | Include as completed. |
| In progress / unresolved | `shipped`, `invoiced`, `processing`, `approved`, `created` | Exclude from the primary completed-revenue measure; optionally report separately as pending order/payment pipeline only with a clear label. | Exclude from the primary completed-repeat count; optionally compare with all-status order counts as a sensitivity check. | Include and report separately by status. |
| Not completed / unavailable | `canceled`, `unavailable` | Exclude from primary completed revenue; retain for operational counts and separately scoped cancellation/unavailability analysis. | Exclude from primary completed-repeat count; retain for a separately labeled all-order behavior check. | Include and report separately, never delete. |

The delivered-only primary rule is conservative, not a claim that every delivered order is fully paid or that `price` equals accounting revenue. Payment measures should be evaluated separately from item prices. For operational summaries, include all eight statuses. If the source contains an unexpected status, preserve it and flag it rather than forcing it into a group silently. The earlier feasibility figure included all order statuses; future repeat-purchase reporting should state its chosen status rule and can show an all-status comparison separately.

## Validation gates for a future clean layer

1. Raw file names, row counts, and checksums remain unchanged.
2. Required IDs are nonblank and unique at the table's documented key grain.
3. Date parse failures, unknown statuses, and numeric parse failures are counted and reviewed.
4. Null counts before and after conversion reconcile; only blank-to-`NULL` conversions are automatic.
5. Child-to-parent key checks report unmatched rows before any exclusion.
6. Exact duplicate removal, if approved for a derived output, records removed counts and source file/fields.
7. Monetary values stay decimal; totals reconcile before and after any transformation.
8. No output is written to `data/raw/`; future derived files go to `data/cleaned/` only after approval.
