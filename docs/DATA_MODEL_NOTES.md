# Olist Data Model Notes

These relationships were checked against the downloaded source CSVs. The descriptions reflect observed file grain and key coverage; they do not create or imply a database schema.

## Table grains

| File | Observed grain | Rows | Identifier notes |
|---|---|---:|---|
| `olist_customers_dataset.csv` | One row per order-specific customer record | 99,441 | `customer_id` unique; `customer_unique_id` repeats for customers represented on multiple orders. |
| `olist_orders_dataset.csv` | One row per order | 99,441 | `order_id` unique; `customer_id` also unique in this snapshot. |
| `olist_order_items_dataset.csv` | One row per order item | 112,650 | `(order_id, order_item_id)` unique. |
| `olist_order_payments_dataset.csv` | One row per payment sequence | 103,886 | `(order_id, payment_sequential)` unique; several rows per order occur. |
| `olist_order_reviews_dataset.csv` | One row per review record | 99,224 | `review_id` and `order_id` repeat; `(review_id, order_id)` was unique in this file. |
| `olist_products_dataset.csv` | One row per product | 32,951 | `product_id` unique. |
| `olist_sellers_dataset.csv` | One row per seller | 3,095 | `seller_id` unique. |
| `olist_geolocation_dataset.csv` | One row per geolocation observation | 1,000,163 | No unique row key identified; postal prefix is highly non-unique. |
| `product_category_name_translation.csv` | One row per translated category | 71 | `product_category_name` unique. |

## Confirmed joins and observed cardinality

| Source → target | Join key | Expected / observed relationship | Key check |
|---|---|---|---|
| `orders` → `customers` | `customer_id` | One order to one customer record in this snapshot; customer record to one order here | All 99,441 order rows matched; no orphan customer IDs. The cross-order customer relationship instead uses `customer_unique_id` in customer records. |
| `orders` → `order_items` | `order_id` | One order to zero or many item rows | All 112,650 item rows matched an order; multiple items per order occur. |
| `orders` → `payments` | `order_id` | One order to one or many payment rows | All 103,886 payment rows matched an order; repeated order IDs occur. |
| `orders` → `reviews` | `order_id` | One order to zero or many review records in the source | All 99,224 review rows matched an order; 551 rows repeat an order ID. |
| `order_items` → `products` | `product_id` | Many item rows to one product | All item product IDs matched a product; product IDs repeat across sold lines. |
| `order_items` → `sellers` | `seller_id` | Many item rows to one seller | All item seller IDs matched a seller. |
| `products` → category translations | `product_category_name` | Many products to zero or one translation row | 71 source category names translated; two observed product categories have no translation. Some products have no category. |

The six tested ID relationships above had zero orphan rows. This is an exact key-membership check against the corresponding source file, not a claim that every business value is semantically correct.

## Geography is not a clean one-to-one dimension

Customer and seller postal prefixes cannot be safely joined directly to a single geolocation row: geolocation contains repeated observations per prefix, 8 prefixes have more than one state among their geolocation rows, and 261,831 geolocation rows are exact repeated rows. In this snapshot, 278 customer prefixes and 7 seller prefixes were absent from geolocation. Also, 35 sellers had a state not represented among geolocation states for their prefix. Any later geographic analysis needs a documented aggregation/mapping approach and should retain the original state fields for comparison.

## Customer identity and retention grain

`customer_id` represents the order-linked customer record. `customer_unique_id` is the available cross-order customer identifier. Retention/repeat counts should count distinct `order_id` values per nonblank `customer_unique_id`, after joining orders to customers by `customer_id`; the current source has one order row per `order_id`. The feasibility count in the quality audit includes every order status and is not a completed-purchase or churn measure.

## Avoiding double counting

Joining order items and payments directly by `order_id` can multiply rows when an order has multiple items and multiple payment records. Aggregate each child table to order grain before combining measures, or preserve line/payment grain and define the intended metric carefully. Review records can also repeat by order. This is a data-grain warning for a future approved analysis phase, not a business result.
