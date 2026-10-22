# Olist Data Dictionary

This dictionary describes the nine source CSV files in `data/raw/`. The files were inspected as delivered and were not changed. Types below are inferred from the source values; date and numeric columns are still text in the original CSVs and need explicit types in any later import.

## `olist_customers_dataset.csv` — 99,441 rows

One record per order-specific `customer_id`. `customer_unique_id` is the dataset's best available cross-order customer identifier.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `customer_id` | Text identifier | Customer record associated with an order | Unique within this file; links to `orders.customer_id`. It is not a durable person identifier across orders. |
| `customer_unique_id` | Text identifier | Anonymized identifier intended to represent a customer across orders | Repeats across customer rows. Use for repeat-purchase feasibility/counting, with documented assumptions. |
| `customer_zip_code_prefix` | Integer-like code | Customer postal-code prefix | Treat as a code, not a quantity; some prefixes do not appear in the geolocation file. |
| `customer_city` | Text | Customer city | Portuguese/local source text; spelling and normalization may vary. |
| `customer_state` | Text code | Brazilian state abbreviation | Geography dimension; values should be validated before grouping. |

No blank values or full-row duplicates were found. There are 96,096 distinct `customer_unique_id` values; repeated values are expected when a person has multiple order-specific customer IDs.

## `olist_orders_dataset.csv` — 99,441 rows

One row per order. This is the order-level table for order status and lifecycle dates.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `order_id` | Text identifier | Order identifier | Unique in this file; joins to items, payments, and reviews. |
| `customer_id` | Text identifier | Customer record for this order | Unique in this file and links to `customers.customer_id`; it does not identify repeat customers by itself. |
| `order_status` | Category text | Observed lifecycle status | Eight observed values: delivered, shipped, canceled, unavailable, invoiced, processing, created, approved. Do not treat every status as a completed sale without defining the rule. |
| `order_purchase_timestamp` | Datetime text | Purchase timestamp | Present and parseable in all rows; spans 2016-09-04 through 2018-10-17. |
| `order_approved_at` | Nullable datetime text | Payment/order approval time | 160 blank values. |
| `order_delivered_carrier_date` | Nullable datetime text | Handoff to carrier time | 1,783 blank values. |
| `order_delivered_customer_date` | Nullable datetime text | Customer delivery time | 2,965 blank values. |
| `order_estimated_delivery_date` | Datetime text | Estimated delivery date | Present and parseable in all rows. |

## `olist_order_items_dataset.csv` — 112,650 rows

One row per item line in an order. An order can have multiple items.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `order_id` | Text identifier | Parent order | Foreign key to `orders.order_id`; repeats by design. |
| `order_item_id` | Integer-like sequence | Item sequence within an order | Composite key component with `order_id`; values repeat across different orders. |
| `product_id` | Text identifier | Product on this line | Foreign key to `products.product_id`; repeats across orders. |
| `seller_id` | Text identifier | Seller fulfilling this line | Foreign key to `sellers.seller_id`; repeats across lines. |
| `shipping_limit_date` | Datetime text | Seller shipping deadline | Present and parseable in all rows. |
| `price` | Decimal | Item price recorded for the line | No missing, zero, or negative values observed; do not infer seller profit. |
| `freight_value` | Decimal | Freight amount charged on the transaction line | 383 zero values; no negatives. Freight value represents freight charged in the transaction and must not be interpreted as seller shipping cost. |

The confirmed composite identifier `(order_id, order_item_id)` is unique for all rows.

## `olist_order_payments_dataset.csv` — 103,886 rows

One row per payment sequence associated with an order. Multiple payment rows per order are possible and observed.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `order_id` | Text identifier | Parent order | Foreign key to `orders.order_id`; repeats for split/multiple payment rows. |
| `payment_sequential` | Integer-like sequence | Payment sequence within an order | Composite key component with `order_id`. |
| `payment_type` | Category text | Payment method label | Observed types include `credit_card`, `boleto`, `voucher`, `debit_card`, and `not_defined`. |
| `payment_installments` | Integer-like count | Installment count | Two zero values observed; verify interpretation before using. |
| `payment_value` | Decimal | Recorded payment amount | Nine zero values; no negatives or blanks. This is payment data, not seller profit. |

The confirmed composite identifier `(order_id, payment_sequential)` is unique.

## `olist_order_reviews_dataset.csv` — 99,224 rows

One review record per row. Review IDs and order IDs can each repeat, so do not assume one review per order or one row per review ID.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `review_id` | Text identifier | Review identifier | Repeats in 814 rows; not unique by itself. |
| `order_id` | Text identifier | Associated order | Repeats in 551 rows; joins to `orders.order_id`. |
| `review_score` | Integer-like score | Customer rating | Values observed are 1–5. |
| `review_comment_title` | Nullable text | Optional review title | 87,656 blanks. |
| `review_comment_message` | Nullable text | Optional review text | 58,247 blanks; may contain free text and line breaks. |
| `review_creation_date` | Datetime text | Review creation date | Present and parseable in all rows. |
| `review_answer_timestamp` | Datetime text | Review response timestamp | Present and parseable in all rows. |

The pair `(review_id, order_id)` is unique in the inspected file, but should be treated as a provisional composite identifier rather than a guaranteed business key.

## `olist_products_dataset.csv` — 32,951 rows

One row per product identifier.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `product_id` | Text identifier | Product identifier | Unique; referenced by order items. |
| `product_category_name` | Nullable category text | Source-language product category | 610 blanks. Two observed category labels have no row in the translation file. |
| `product_name_lenght` | Nullable integer-like | Source field describing product-name length | Source spelling is `lenght`; 610 blanks. |
| `product_description_lenght` | Nullable integer-like | Product-description length | 610 blanks. |
| `product_photos_qty` | Nullable integer-like | Number of product photos | 610 blanks. |
| `product_weight_g` | Nullable integer-like | Product weight in grams | 2 blanks and 4 zero values. |
| `product_length_cm` | Nullable integer-like | Product length in centimeters | 2 blanks. |
| `product_height_cm` | Nullable integer-like | Product height in centimeters | 2 blanks. |
| `product_width_cm` | Nullable integer-like | Product width in centimeters | 2 blanks. |

## `olist_sellers_dataset.csv` — 3,095 rows

One row per seller.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `seller_id` | Text identifier | Seller identifier | Unique; referenced by order items. |
| `seller_zip_code_prefix` | Integer-like code | Seller postal-code prefix | Treat as a code; 7 seller prefixes were absent from the geolocation file. |
| `seller_city` | Text | Seller city | Local source spelling; normalization may be needed later. |
| `seller_state` | Text code | Brazilian state abbreviation | 35 seller records have a state not represented among geolocation states for their prefix. This is a mapping concern, not proof the seller row is invalid. |

## `olist_geolocation_dataset.csv` — 1,000,163 rows

One row per geolocation observation, not one row per postal prefix. The file contains 261,831 repeated full rows. No unique primary key was identified.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `geolocation_zip_code_prefix` | Integer-like code | Postal-code prefix | Repeats many times; 8 prefixes have more than one state value. Do not join as if unique. |
| `geolocation_lat` | Decimal | Latitude observation | Repeated and variable by prefix. |
| `geolocation_lng` | Decimal | Longitude observation | Repeated and variable by prefix. |
| `geolocation_city` | Text | City observation for a prefix | Repeated observations and inconsistent mapping are possible. |
| `geolocation_state` | Text code | State observation for a prefix | Repeated observations; use a documented aggregation/mapping rule if needed later. |

## `product_category_name_translation.csv` — 71 rows

One row per translated product category label.

| Column | Inferred type | Meaning and analytical role | Key / caveat |
|---|---|---|---|
| `product_category_name` | Text category | Source-language category label | Unique in this file; joins by label to products. |
| `product_category_name_english` | Text category | English translation | Translation coverage is incomplete: two product categories are not present. |

## Identifier note: `customer_id` versus `customer_unique_id`

`customer_id` is a unique customer record associated with an order; each order in this dataset points to a different `customer_id`. The same `customer_unique_id` appears across those records when the source believes they represent the same customer. Use `customer_unique_id` for repeat-customer counting, and state that it is an anonymized source identifier rather than verified real-world identity. The inspection found 99,441 distinct `customer_id` values but 96,096 distinct `customer_unique_id` values.
