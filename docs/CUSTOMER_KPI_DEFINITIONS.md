# RetailPulse Customer KPI Definitions

These definitions apply to `sql/06_customer_analysis.sql`. The primary purchase population is orders with `order_status = 'delivered'`. Customer identity across orders is `customers.customer_unique_id`; `customer_id` links one order to its order-specific customer record.

Customer revenue means delivered order-item price only. For each order, item prices are summed first; those order totals are then summed to customer grain. Freight and `payments.payment_value` are excluded. No KPI below is a churn measure or a causal claim.

## Delivered Customer

- **Definition:** A source-defined customer with at least one delivered order.
- **Grain:** One `customer_unique_id` with one or more delivered `order_id` values.
- **Filter:** `orders.order_status = 'delivered'`.
- **Formula:** Count distinct `customer_unique_id` after joining each order to `customers` by `customer_id`.
- **Caveats:** `customer_unique_id` is an anonymized dataset identity, not verified real-world identity. Non-delivered orders do not qualify.

## Repeat Customer

- **Definition:** A delivered customer with at least two delivered orders.
- **Grain:** One row per `customer_unique_id` after counting delivered orders.
- **Filter:** Delivered orders only.
- **Formula:** `delivered_orders >= 2`.
- **Caveats:** Customers with one delivered order are one-time customers for this observed dataset. They are not labelled churned.

## Repeat Customer Rate

- **Definition:** Percentage of delivered customers who have at least two delivered orders.
- **Grain:** Customer.
- **Filter:** Delivered customers form the denominator.
- **Formula:** `repeat_customers / delivered_customers * 100`.
- **Caveats:** This is descriptive of the available order history and observation window. It is not retention probability or churn rate.

## Customer Revenue

- **Definition:** Sum of the customer's delivered order-level item-price totals.
- **Grain:** Aggregate order-item `price` to `order_id`, then aggregate orders by `customer_unique_id`.
- **Filter:** Delivered orders only.
- **Formula:** `SUM(order_revenue)`, where `order_revenue = SUM(order_items.price)` per order.
- **Caveats:** Excludes freight, payment records, non-delivered orders, and profit/cost. Orders with no item rows, if any, contribute zero in the customer-level order set.

## Customer Average Order Value

- **Definition:** Average delivered item-price revenue per delivered order for a customer.
- **Grain:** One customer row after aggregating each delivered order's item lines.
- **Filter:** Delivered orders only.
- **Formula:** `customer_revenue / delivered_orders`.
- **Caveats:** It is not an average over item rows. Freight and payment values are excluded. It does not represent profit or necessarily cash collected.

## Purchase Frequency

- **Definition:** Number of delivered orders associated with one source-defined customer.
- **Grain:** `customer_unique_id`.
- **Filter:** Delivered orders only.
- **Formula:** Count delivered order rows per customer after joining `orders` to `customers` on `customer_id`.
- **Caveats:** An `order_items` join is not used to count orders; multiple item lines must not inflate the count. Frequency buckets are 1, 2, 3, 4, and 5+ delivered orders.

## First Purchase

- **Definition:** A customer's earliest delivered order by `order_purchase_timestamp`.
- **Grain:** One first delivered `order_id` per `customer_unique_id`.
- **Filter:** Delivered orders only.
- **Formula:** `ROW_NUMBER()` partitioned by `customer_unique_id`, ordered by purchase timestamp and then `order_id`; sequence 1 is the first purchase. The date is the `DATE()` of that order's timestamp.
- **Caveats:** `order_id` provides a stable tie-break when timestamps match. It makes the first order deterministic without claiming which tied order happened first in real time.

## Repeat Purchase

- **Definition:** A delivered order after the customer's first delivered order.
- **Grain:** Delivered order within a customer's timestamp-ordered purchase sequence.
- **Filter:** Delivered orders only.
- **Formula:** `ROW_NUMBER() > 1` within `customer_unique_id`, ordered by purchase timestamp and `order_id`.
- **Caveats:** A customer with a first and later order in the same month can count in both monthly new-customer and repeat-customer counts. Revenue is assigned to each order's sequence class. A repeat purchase is not an additional item row.

## Days Between Purchases

- **Definition:** Calendar days between consecutive delivered purchase dates for a customer.
- **Grain:** One interval between adjacent delivered orders for a `customer_unique_id`.
- **Filter:** Customers' second and later delivered orders; `LAG()` supplies the previous purchase date.
- **Formula:** `DATEDIFF(current_order_date, previous_order_date)`.
- **Caveats:** Same-calendar-day orders have a zero-day interval. This measures observed gaps; the 0–30, 31–60, 61–90, 91–180, and 181+ day buckets are not churn thresholds.

## Customer Category Breadth

- **Definition:** Number of distinct source product categories appearing on a customer's delivered item lines.
- **Grain:** One `customer_unique_id`, counting distinct `products.product_category_name` values.
- **Filter:** Item lines belonging to delivered orders.
- **Formula:** `COUNT(DISTINCT product_category_name)` per customer.
- **Caveats:** Null product categories are excluded rather than treated as a category. This uses source category labels, not translated names. A comparison between one-time and repeat customers is descriptive and does not imply causation.

## Revenue Concentration

- **Definition:** Share of delivered customer revenue represented by the top-ranked 1%, 5%, or 10% of delivered customers, plus each customer's cumulative revenue contribution.
- **Grain:** One customer revenue total per `customer_unique_id`.
- **Filter:** Delivered orders only.
- **Formula:** Sort revenue descending, break ties by `customer_unique_id`, and select exactly `CEIL(percent * delivered_customer_count)` customers. Divide the selected customers' revenue by total delivered customer revenue. Cumulative contribution uses a running `SUM()` over the same ordering.
- **Caveats:** The row-number rule selects an exact customer count even when revenues tie; tied customers can fall on opposite sides of a cutoff. These are descriptive concentration measures, not customer segments or a recommendation.

## Recency / Observed Inactivity

- **Definition:** Calendar days between a customer's last delivered purchase date and the latest delivered purchase date present in the dataset.
- **Grain:** One delivered customer.
- **Filter:** Delivered orders only.
- **Formula:** `DATEDIFF(dataset_max_delivered_purchase_date, customer_last_purchase_date)`; grouped into 0–30, 31–60, 61–90, 91–180, and 181+ day recency bands.
- **Caveats:** This is dataset-relative observed recency, not days since today. Olist data is historical and incomplete outside its observation window, so the bands are not churn labels or predictions.
