# RetailPulse Power BI KPI Validation Plan

Power BI must reproduce the existing SQL and Python definitions. Phase 9's KPI CSV/notes contain results calculated from raw CSVs, but no saved SQL query outputs are present. Python values below are checkpoints only; they do not prove numeric equality to SQL. Run the matching MySQL queries with the same filters and grain before marking a Power BI KPI SQL-validated.

## KPI validation matrix

| KPI | Source definition | Power BI source | Filter and grain | Validation |
|---|---|---|---|---|
| Delivered Revenue | Sum `order_items.price` for delivered orders; freight and payments excluded. | `[Delivered Revenue]`, `FactOrderItems`. | Delivered status, item-line sum. Date/customer/product/seller filters apply. | Compare to Phase 6 delivered item-price query. Python checkpoint: `13,221,498.11`; SQL result not saved. |
| Delivered Orders | Count order records where status is delivered. | `[Delivered Orders]`, `FactOrders`. | One row/order; date/customer filters. Product filter does not change this order-grain measure by default. | Compare to Phase 6 count query. Python checkpoint: `96,478`. Check for delivered orders without item lines; `FactOrders` preserves them. |
| Delivered Customers | Distinct `customer_unique_id` among delivered orders. | `[Delivered Customers]`, `FactOrders`. | Customer identity, not customer-record key. | Compare to Phase 6 delivered-customer query. Python checkpoint: `93,358`. |
| Average Order Value | Aggregate item price per delivered order, then average the order totals. A no-line order contributes zero. | `[Average Order Value]`, `FactOrders[order_item_revenue]`. | One value/order; never average item lines. | Compare to Phase 6 order-grain AOV query. Python checkpoint: `137.0415857501192` (about `137.04`). |
| Repeat Customer Rate | Delivered customers with 2+ delivered orders divided by all delivered customers; identity is `customer_unique_id`. | `[Repeat Customer Rate]`, `CustomerMetrics`. | Full observed window; the standalone summary is not sliced by state/product/date. | Compare with Phase 7 repeat-customer and Phase 8 second-purchase-rate queries. Python checkpoint: `3.0002784978%`; SQL numeric result not provided. |
| Monthly Revenue | Delivered item-price revenue grouped by order purchase month; empty months are zero. | `[Monthly Revenue]`, `FactOrderItems` plus `DimDate`. | Item lines, purchase month, no freight. | Compare month-by-month to Phase 6 monthly output, including zero months. Python produced 24 calendar months and an internal zero month at `2016-11`; first/last periods are partial. |
| Category Revenue | Delivered item-price sum by translated category, fallback to original category, then `Unknown`. | `[Category Revenue]` by `DimProducts`. | Item-line grain; keep uncategorized products. | Compare with Phase 6 category output; totals should reconcile to delivered revenue and fallback labels. Product names are unavailable. |
| State Revenue | Delivered item-price sum attributed to state in the order-linked customer record. | `[State Revenue]` by `DimCustomers[customer_state]`. | Item-price revenue grouped by customer record state. | Compare with Phase 6 state query. Confirm state totals sum to delivered revenue; do not join geolocation or payment rows. |
| Cohort Retention | Distinct active delivered customers in cohort/elapsed month divided by original cohort size; immature horizons are `NULL` in mature comparisons. | Imported `CohortRetention`, key `(cohort_month, month_number)`. | One row per cohort and month offset. | Compare cells to Phase 8 Sections E/F. Check month 0 = 100%, no value > 100%, no negative offset, and immature horizons blank. Do not sum percentages or average cohorts without an explicit weighting rule. |

Also validate item lines against Phase 6 (they are lines, not physical quantity), monthly new/repeat counts and revenue against Phase 7 Section C, and second-purchase timing against Phase 8 Section I. A customer can have a first and later delivered order in the same month and count in both monthly classes. A multi-month sum of monthly repeat-customer counts is customer-month activity, not unique customers.

## Validation workflow

1. Refresh Power BI from the same `retailpulse` database state used for SQL validation.
2. Run the matching read-only SQL query and save results locally for comparison; do not include credentials in query exports.
3. Match delivered status, purchase-date basis, category fallback, customer identity, and grain exactly.
4. Compare raw values before display rounding. Check item-line revenue, order-grain AOV/count, unique-customer count, and cohort/offset values separately.
5. Test date, state, and category slicers independently. Confirm the documented limitations of precomputed summaries.
6. Record actual comparisons only after they have been run. A Python-definition match alone is not a SQL numeric validation.

## Limitations to preserve

- Phase 9 read raw CSVs rather than MySQL. It followed the approved definitions, but numeric equality with SQL was not established in stored outputs.
- `CustomerMetrics` is full-window; monthly customer activity is pre-aggregated and not product/state sliced. Label accordingly.
- Retention is observed only inside this historical data window. No observed purchase does not prove churn; newer cohorts have less follow-up and immature horizons stay blank.
- Freight is a transaction value, not seller cost. No true cost/profit field exists.
