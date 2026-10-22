# MySQL 8 Analytical Schema

## Purpose and scope

This document records the original schema design. In Phase 5, the `retailpulse` database and eight core tables were created, loaded, and validated. See `docs/IMPORT_VALIDATION.md` for the confirmed row counts and technical checks. The design details below preserve the intended table grains and constraints.

The implemented tables use `InnoDB`, `utf8mb4`, explicit `NOT NULL`/`NULL`, foreign keys for confirmed relationships, and exact `DECIMAL` types for currency. Identifiers remain strings; postal prefixes are strings to preserve leading zeroes. The lengths shown below were used in the Phase 5 DDL. Check source maxima before future schema changes, and never truncate source values to fit a chosen type.

## Core tables

### `customers`

- **Source:** `olist_customers_dataset.csv`; **grain:** one order-specific customer record.
- **Primary key:** `customer_id`.
- **Foreign keys:** none.
- **Columns:** `customer_id VARCHAR(32) NOT NULL`; `customer_unique_id VARCHAR(32) NOT NULL`; `customer_zip_code_prefix CHAR(5) NULL`; `customer_city VARCHAR(100) NOT NULL`; `customer_state CHAR(2) NOT NULL`.
- **Constraints / purpose:** PK on `customer_id`; index `customer_unique_id`; do not make `customer_unique_id` unique. Keep source location because it is customer-record location, not necessarily a normalized geography key.

### `orders`

- **Source:** `olist_orders_dataset.csv`; **grain:** one row per order.
- **Primary key:** `order_id`.
- **Foreign keys:** `customer_id` → `customers.customer_id`.
- **Columns:** `order_id VARCHAR(32) NOT NULL`; `customer_id VARCHAR(32) NOT NULL`; `order_status VARCHAR(20) NOT NULL`; `order_purchase_timestamp DATETIME NOT NULL`; `order_approved_at DATETIME NULL`; `order_delivered_carrier_date DATETIME NULL`; `order_delivered_customer_date DATETIME NULL`; `order_estimated_delivery_date DATETIME NOT NULL`.
- **Constraints / purpose:** PK and customer FK. `customer_id` was unique in the observed snapshot; a `UNIQUE(customer_id)` constraint is optional and should be applied only if the project intends to enforce the source's one-order-per-customer-record property. Preserve all statuses. Index purchase time and status for later filtering.

### `products`

- **Source:** `olist_products_dataset.csv`; **grain:** one row per product.
- **Primary key:** `product_id`.
- **Foreign keys:** none in the core design. Category translation is intentionally a left-join lookup because translation coverage is incomplete.
- **Columns:** `product_id VARCHAR(32) NOT NULL`; `product_category_name VARCHAR(100) NULL`; `product_name_lenght INT NULL`; `product_description_lenght INT NULL`; `product_photos_qty INT NULL`; `product_weight_g INT NULL`; `product_length_cm INT NULL`; `product_height_cm INT NULL`; `product_width_cm INT NULL`.
- **Constraints / purpose:** PK on `product_id`; nullable source metadata stays nullable. Preserve the misspelled source column spelling in an import mapping or document a consistent corrected target name before import.

### `sellers`

- **Source:** `olist_sellers_dataset.csv`; **grain:** one row per seller.
- **Primary key:** `seller_id`.
- **Foreign keys:** none.
- **Columns:** `seller_id VARCHAR(32) NOT NULL`; `seller_zip_code_prefix CHAR(5) NULL`; `seller_city VARCHAR(100) NOT NULL`; `seller_state CHAR(2) NOT NULL`.
- **Constraints / purpose:** PK on `seller_id`; retain source locations as given and do not replace them with geolocation-derived values.

### `order_items`

- **Source:** `olist_order_items_dataset.csv`; **grain:** one row per order item.
- **Primary key:** composite `(order_id, order_item_id)`; this pair was unique in the inspected source.
- **Foreign keys:** `order_id` → `orders.order_id`; `product_id` → `products.product_id`; `seller_id` → `sellers.seller_id`.
- **Columns:** `order_id VARCHAR(32) NOT NULL`; `order_item_id SMALLINT NOT NULL`; `product_id VARCHAR(32) NOT NULL`; `seller_id VARCHAR(32) NOT NULL`; `shipping_limit_date DATETIME NOT NULL`; `price DECIMAL(12,2) NOT NULL`; `freight_value DECIMAL(12,2) NOT NULL`.
- **Constraints / purpose:** composite PK and three FKs; indexes on product and seller FKs. `price` and freight remain distinct. This is the candidate central transaction fact grain for later analytics.

### `payments`

- **Source:** `olist_order_payments_dataset.csv`; **grain:** one row per payment sequence for an order.
- **Primary key:** composite `(order_id, payment_sequential)`; unique in the inspected source.
- **Foreign keys:** `order_id` → `orders.order_id`.
- **Columns:** `order_id VARCHAR(32) NOT NULL`; `payment_sequential SMALLINT NOT NULL`; `payment_type VARCHAR(30) NOT NULL`; `payment_installments SMALLINT NOT NULL`; `payment_value DECIMAL(12,2) NOT NULL`.
- **Constraints / purpose:** composite PK and order FK. Keep payment facts at payment grain; do not force one payment row per order.

### `reviews`

- **Source:** `olist_order_reviews_dataset.csv`; **grain:** one review record row.
- **Primary key:** composite `(review_id, order_id)`, validated as unique in the inspected CSV. Revalidate during staging; if it fails, stop and investigate rather than silently merging rows or inventing an ID.
- **Foreign keys:** `order_id` → `orders.order_id`.
- **Columns:** `review_id VARCHAR(32) NOT NULL`; `order_id VARCHAR(32) NOT NULL`; `review_score TINYINT UNSIGNED NOT NULL`; `review_comment_title TEXT NULL`; `review_comment_message TEXT NULL`; `review_creation_date DATETIME NOT NULL`; `review_answer_timestamp DATETIME NOT NULL`.
- **Constraints / purpose:** composite PK, order FK, and a validation rule for score 1–5. Repeated review IDs and order IDs are valid at row level; optional text remains nullable.

### `product_category_translations`

- **Source:** `product_category_name_translation.csv`; **grain:** one translated mapping per source category name.
- **Primary key:** `product_category_name` (unique in the source file).
- **Foreign keys:** none from `products` in the initial design, because product values include two categories absent from the translation file and some category values are null.
- **Columns:** `product_category_name VARCHAR(100) NOT NULL`; `product_category_name_english VARCHAR(100) NOT NULL`.
- **Constraints / purpose:** lookup for a left join. When no match exists, preserve and display the product's source-language category instead of making up a translation.

## Geolocation decision

Do **not** load the raw `olist_geolocation_dataset.csv` into the core analytical schema in the first import. It has no unique key, contains 261,831 repeated full rows, and a postal prefix may map to multiple points or, for 8 prefixes, multiple states. The customer and seller files already contain city/state attributes that can support coarse regional grouping without a risky raw geolocation join.

If map coordinates are later required, create a separately documented derived lookup such as `geolocation_prefix_lookup`, one row per postal prefix, only after agreeing and validating an aggregation rule. Candidate design: `postal_code_prefix CHAR(5) PRIMARY KEY`, nullable representative `latitude DECIMAL(10,7)` and `longitude DECIMAL(10,7)`, nullable city/state only where the mapping is unambiguous, plus `mapping_conflict BOOLEAN NOT NULL`. Reconcile source row counts and flag ambiguous prefixes. Do not treat a median/centroid as an exact customer or seller address.

## Primary-key and grain safeguards

- Do not use `order_id` alone as the PK for items, payments, or reviews: multiple rows per order are part of their observed grains.
- The validated item key is `(order_id, order_item_id)`; payment key is `(order_id, payment_sequential)`; review candidate is `(review_id, order_id)`.
- Geolocation has no safe source natural key at row grain; excluding it from the core avoids inventing one. A derived prefix lookup has a natural one-row-per-prefix key only after aggregation policy is approved.
- The source IDs are 32-character text identifiers; store them as `VARCHAR(32)`, not numeric values.
- No surrogate key is needed for the core tables with validated natural/composite keys. Reassess only if future source records break these keys or an application requires a stable row identity.

## Analytical Model Direction

The relational model can later feed a Power BI star-style model. A likely central fact is `order_items`, at **one row per order item**, with dimensions for customer, product, seller, order/status, and purchase date. The same order header can provide role-playing dates (purchase, approval, delivery) with a clearly selected active date relationship. Payments and reviews should remain separate fact-like tables at payment and review grain rather than being flattened into item rows.

Never directly join `payments` to `order_items` by `order_id` for additive measures without first aggregating or otherwise preserving grain. If one order has 3 item rows and 2 payment rows, that join creates 3 × 2 = 6 joined rows. Each item and each payment is repeated, which can inflate both item-price and payment totals. Aggregate payments to one row per order before a deliberate order-grain comparison, or keep the facts separate in the BI model. The same fan-out risk applies to reviews and geolocation.

## Customer modeling rule

`customer_id` is the order-linked customer record and joins an order to `customers`. `customer_unique_id` is the source's cross-order customer identity. Future customer-level repeat counts should use `customer_unique_id`, count distinct orders, and state the order-status inclusion rule. Do not count `customer_id` as unique people across orders.

## Import and constraint notes

For future schema changes, verify max string lengths, integer ranges, and decimal precision/scale from the original files, map every source column explicitly, and test that composite keys remain unique after any approved transformation. Import order should satisfy parent tables before child tables: customers/products/sellers, then orders, then order items/payments/reviews; translations can load independently. Use a staging/validation step before adding constraints if it helps diagnose errors, but retain the source and report rejected rows. Phase 5 implementation and import validation are recorded in `docs/IMPORT_VALIDATION.md`.
