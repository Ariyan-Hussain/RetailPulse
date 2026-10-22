# Initial Olist Data Quality Audit

## Scope and method

This is a read-only structural audit of the nine downloaded CSV files in `data/raw/`. The source files were not modified. Counts below come from CSV parsing, full-row duplicate detection, identifier/composite-key checks, timestamp parsing, and key-membership checks. No cleaning, SQL database, KPI analysis, or business conclusion was performed.

## File inventory and quality findings

| File | Rows × columns | Missing values | Duplicate / identifier findings | Other checks and concerns |
|---|---:|---|---|---|
| `olist_customers_dataset.csv` | 99,441 × 5 | None | 0 full-row duplicates; 99,441 unique `customer_id`; 96,096 distinct `customer_unique_id` (3,345 repeated rows beyond first occurrences) | Customer postal prefixes are codes, not numeric measures. 278 prefixes did not occur in geolocation. |
| `olist_geolocation_dataset.csv` | 1,000,163 × 5 | None | 261,831 repeated full rows; no single unique key | 8 postal prefixes map to more than one state in the file. Data is repeated point observations, not a postal-code dimension. |
| `olist_order_items_dataset.csv` | 112,650 × 7 | None | 0 full-row duplicates; `(order_id, order_item_id)` unique | 383 `freight_value` values are zero; none negative. `price` range observed: 0.85–6,735.00. Freight charged is not seller shipping cost. |
| `olist_order_payments_dataset.csv` | 103,886 × 5 | None | 0 full-row duplicates; `(order_id, payment_sequential)` unique; order IDs repeat | 2 zero installment counts and 9 zero payment values. No negative payment values observed. |
| `olist_order_reviews_dataset.csv` | 99,224 × 7 | 87,656 blank titles; 58,247 blank messages | 0 full-row duplicates; `review_id` repeats in 814 rows; `order_id` repeats in 551 rows; `(review_id, order_id)` unique in this file | Scores range 1–5. Review text is optional and may contain multiline text. |
| `olist_orders_dataset.csv` | 99,441 × 8 | 160 approval dates; 1,783 carrier dates; 2,965 delivery dates | 0 full-row duplicates; `order_id` and `customer_id` each unique | Eight observed statuses: delivered, shipped, canceled, unavailable, invoiced, processing, created, approved. All nonblank date values parsed. Purchase timestamps span 2016-09-04 through 2018-10-17. |
| `olist_products_dataset.csv` | 32,951 × 9 | Category and three text/metadata fields: 610 each; weight and three dimensions: 2 each | 0 full-row duplicates; `product_id` unique | 4 zero product weights. Two categories have no English translation. Source header spells `product_name_lenght`. |
| `olist_sellers_dataset.csv` | 3,095 × 4 | None | 0 full-row duplicates; `seller_id` unique | 7 seller postal prefixes absent from geolocation; 35 seller state values not found among the geolocation states for their prefix. |
| `product_category_name_translation.csv` | 71 × 2 | None | 0 full-row duplicates; source category label unique | Products contain 73 distinct nonblank categories; `pc_gamer` and `portateis_cozinha_e_preparadores_de_alimentos` lack translations. |

## Relationship checks

| Reference checked | Rows checked | Orphan rows |
|---|---:|---:|
| `orders.customer_id` → `customers.customer_id` | 99,441 | 0 |
| `order_items.order_id` → `orders.order_id` | 112,650 | 0 |
| `payments.order_id` → `orders.order_id` | 103,886 | 0 |
| `reviews.order_id` → `orders.order_id` | 99,224 | 0 |
| `order_items.product_id` → `products.product_id` | 112,650 | 0 |
| `order_items.seller_id` → `sellers.seller_id` | 112,650 | 0 |

These checks establish key membership only. They do not prove that source records are otherwise correct or that an analytical join will avoid double-counting.

## Timestamp and numeric checks

All populated values in the inspected date/time fields parsed successfully. Missing timestamps are listed in the inventory above; they are not automatically errors, because some orders may not reach every lifecycle stage. No negative values were found in the checked `price`, `freight_value`, `payment_value`, installment, review-score, or product-dimension/weight fields. The observed zero values noted above need a later business-rule decision rather than automatic correction.

## Repeat-customer feasibility

Method: join every row in `orders` to `customers` on `customer_id`, group order rows by `customer_unique_id`, and count orders without filtering by `order_status`.

| Measure | Observed value |
|---|---:|
| Distinct customers (`customer_unique_id`) represented in orders | 96,096 |
| Customers with exactly one order | 93,099 |
| Customers with two or more orders | 2,997 |
| Repeat customers as a share of represented unique customers | 3.1188% |
| Maximum orders for one `customer_unique_id` | 17 |

This supports the feasibility of a carefully scoped repeat-purchase analysis. It does not establish churn, customer loyalty, reasons for repeat behavior, or cohort retention quality. All order statuses were included, so a later analysis must define which statuses count as purchases.

## Scope and interpretation guardrails

- The selected Olist dataset does not contain true seller cost or profit data, so profitability metrics are intentionally excluded.
- Freight value represents freight charged in the transaction and must not be interpreted as seller shipping cost.
- Do not claim churn or causation from these observational files.
- Keep original CSVs unchanged. Cleaning, schema design, SQL, KPI analysis, and dashboards belong to later approved phases.
