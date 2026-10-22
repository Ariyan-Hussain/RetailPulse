# RetailPulse Foundational KPI Definitions

These definitions apply to the Phase 6 queries in `sql/05_analysis_foundation.sql`. The primary completed-order population is `orders.order_status = 'delivered'`. Unless a KPI explicitly describes all statuses, other statuses are excluded.

## Revenue and order KPIs

### Total Delivered Revenue

- **Definition:** Sum of item prices on delivered orders.
- **SQL grain:** `order_items` row (one item line), filtered through its parent order.
- **Filter:** Parent `orders.order_status = 'delivered'`.
- **Numerator:** `SUM(order_items.price)`.
- **Denominator:** Not applicable.
- **Caveats:** In this project, revenue currently means delivered item price: `SUM(order_items.price)`. It excludes freight, canceled/unavailable and other non-delivered orders, payment-processing concepts, and profit/cost. It is not claimed to be accounting or cash-collected revenue.

### Total Orders

- **Definition:** Count of order records across every observed status.
- **SQL grain:** One row per `orders.order_id`.
- **Filter:** None.
- **Numerator / denominator:** Not applicable.
- **Caveats:** Status distribution should be shown when this count is used as context.

### Delivered Orders

- **Definition:** Number of orders with status `delivered`.
- **SQL grain:** One row per order.
- **Filter:** `order_status = 'delivered'`.
- **Numerator:** Count of delivered order rows.
- **Denominator:** Not applicable unless used in a rate.
- **Caveats:** Delivered status is the project's conservative completed-order filter; it does not prove every order was fully paid.

### Delivered Order Percentage

- **Definition:** Share of all order records whose status is delivered.
- **SQL grain:** One row per order.
- **Filter:** Numerator filters delivered; denominator includes all statuses.
- **Numerator:** Delivered order count.
- **Denominator:** Total order count.
- **Caveats:** Not a payment-completion or customer-satisfaction rate.

### Delivered Item Lines

- **Definition:** Number of `order_items` rows associated with delivered orders.
- **SQL grain:** One order-item line.
- **Filter:** Parent order status is delivered.
- **Numerator / denominator:** Not applicable.
- **Caveats:** The dataset has no true quantity column. This is a count of item lines, not a verified count of physical units.

### Average Item Price

- **Definition:** Average item-line price for delivered orders.
- **SQL grain:** One order-item line.
- **Filter:** Parent order status is delivered.
- **Numerator:** Sum of delivered item-line prices.
- **Denominator:** Count of delivered item lines.
- **Caveats:** Each line receives equal weight; it is not AOV. Freight is excluded.

### Average Order Value (AOV)

- **Definition:** Average delivered item-price revenue per delivered order.
- **SQL grain:** First aggregate item lines to one row per `order_id`, then average `order_revenue` across delivered orders.
- **Filter:** `order_status = 'delivered'`.
- **Numerator:** Sum of delivered order revenue.
- **Denominator:** Number of delivered orders.
- **Caveats:** `order_revenue` is the sum of `order_items.price`; freight and `payments.payment_value` are excluded. Orders without item rows, if any, are represented as zero item-price revenue in order-grain summaries.

### Median Delivered Order Revenue

- **Definition:** Middle delivered order-revenue value; for an even number of orders, average the two middle values.
- **SQL grain:** One row per delivered order after item-price aggregation.
- **Filter:** `order_status = 'delivered'`.
- **Numerator / denominator:** Not applicable; calculated by ranking order-level values.
- **Caveats:** Uses the same item-price definition as AOV and can be zero for a delivered order with no item rows.

### Monthly Revenue

- **Definition:** Sum of delivered item-price revenue grouped by the order purchase month (`YYYY-MM`).
- **SQL grain:** Aggregate item lines to order first; then aggregate orders by purchase month. The monthly series fills calendar gaps with zero revenue and zero counts.
- **Filter:** `order_status = 'delivered'`.
- **Numerator:** Sum of order-level delivered item-price revenue in that month.
- **Denominator:** Not applicable.
- **Caveats:** Month is based on `order_purchase_timestamp`, not delivery date, payment date, or accounting period. Freight and payment values are excluded.

### Month-over-Month Revenue Growth

- **Definition:** Percentage change in monthly delivered item-price revenue from the immediately prior calendar month.
- **SQL grain:** One calendar-month revenue row, compared with the prior month using `LAG()`; months without delivered orders are represented as zero revenue.
- **Filter:** Delivered orders only.
- **Numerator:** Current month revenue minus previous month revenue.
- **Denominator:** Previous month revenue.
- **Caveats:** Formula is `(current - previous) / NULLIF(previous, 0) * 100`. The first month has no previous value and therefore returns `NULL`; zero prior revenue also returns `NULL`. No growth value is invented.

## Customer KPIs

### Unique Customers

- **Definition:** Count of distinct source-defined `customer_unique_id` values in the customer table.
- **SQL grain:** Cross-order customer identity (`customer_unique_id`).
- **Filter:** None for the all-status overview.
- **Numerator:** Count of distinct customer identifiers.
- **Denominator:** Not applicable.
- **Caveats:** This anonymized source identifier is the best available cross-order identity, not verified real-world identity. Do not substitute `customer_id`, which is order-specific in this dataset.

### Delivered Customers

- **Definition:** Distinct source-defined customers with at least one delivered order.
- **SQL grain:** Join order records to customer records by `customer_id`, then count distinct `customer_unique_id`.
- **Filter:** `order_status = 'delivered'`.
- **Numerator:** Distinct delivered-ordering `customer_unique_id` values.
- **Denominator:** Not applicable.
- **Caveats:** A customer with multiple delivered orders counts once.

## Category, product, and regional KPIs

### Category Revenue

- **Definition:** Delivered item-price revenue grouped by product category.
- **SQL grain:** One item line, grouped by translated category where available.
- **Filter:** Parent order status is delivered.
- **Numerator:** `SUM(order_items.price)` for the category.
- **Denominator:** Not applicable for revenue; category revenue percentage divides by total delivered item-price revenue across categories.
- **Caveats:** Translation uses a `LEFT JOIN`; label falls back to source category, then `Unknown`. Freight is excluded. Category order counts use distinct orders; item counts use item lines. Low revenue alone does not mean poor performance.

### Product Revenue

- **Definition:** Delivered item-price revenue grouped by product ID.
- **SQL grain:** One item line, grouped by `product_id`.
- **Filter:** Parent order status is delivered.
- **Numerator:** Sum of item-line prices for the product.
- **Denominator:** Not applicable.
- **Caveats:** Product names are not present in this schema; do not invent them. Product order counts are distinct orders containing the product, while item count is item lines.

### State Revenue

- **Definition:** Delivered item-price revenue attributed to the state in the order-linked customer record.
- **SQL grain:** Sum item prices to one row per order, then group orders by `customers.customer_state`.
- **Filter:** `order_status = 'delivered'`.
- **Numerator:** Sum of order-level item-price revenue for the state.
- **Denominator:** Not applicable for revenue. State AOV is the average order-level revenue; unique customers count distinct `customer_unique_id`.
- **Caveats:** This uses customer-file state, not a geolocation-derived mapping. AOV must be calculated at order grain to prevent multiple item rows from weighting large orders more heavily.

## Measures intentionally kept separate

- **Freight:** `order_items.freight_value` is freight charged in the transaction; it is not seller shipping cost.
- **Payments:** `payments.payment_value` is a payment-record amount. Multiple payment rows can belong to an order, so payment data must remain at payment grain or be aggregated deliberately. It is not automatically interchangeable with item-level revenue.
- **Profit and cost:** The dataset has no true seller cost or profit fields. Do not calculate profit or profit margin.
- **Excluded order statuses:** Canceled, unavailable, and other non-delivered orders remain in the database and in all-status order counts; they are excluded from the foundational delivered revenue measures.
