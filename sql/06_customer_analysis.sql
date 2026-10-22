-- RetailPulse Phase 7: advanced customer and repeat-purchase analysis (MySQL 8).
-- Customer identity is customer_unique_id across order-specific customer_id rows.
-- The primary completed-purchase population is delivered orders.
-- Customer revenue is delivered order-item price only; freight and payments
-- are excluded. No query labels customers as churned or makes causal claims.
--
-- The customer_summary CTE is repeated in standalone statements because MySQL
-- CTEs have statement scope. It produces one row per delivered customer.

USE retailpulse;

-- ============================================================================
-- SECTION A: PURCHASE FREQUENCY
-- ============================================================================

-- Business questions 1-4: How many customers had one versus repeat delivered
-- purchases, what is the repeat-customer rate, and what is the maximum order
-- count? Order items are first aggregated to order grain; the final CTE is one
-- row per customer_unique_id, so customers with more items are not duplicated.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
)
SELECT COUNT(CASE WHEN delivered_orders = 1 THEN 1 END)
           AS one_time_delivered_customers,
       COUNT(CASE WHEN delivered_orders >= 2 THEN 1 END)
           AS repeat_delivered_customers,
       COUNT(*) AS total_delivered_customers,
       ROUND(
           100.0 * COUNT(CASE WHEN delivered_orders >= 2 THEN 1 END)
           / NULLIF(COUNT(*), 0),
           2
       ) AS repeat_customer_rate_pct,
       MAX(delivered_orders) AS maximum_delivered_orders_per_customer
FROM customer_summary;

-- Business question 5: What is the distribution of delivered purchase counts?
-- Each customer appears once; 5+ combines all counts of five or more.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
),
frequency_buckets AS (
    SELECT CASE
               WHEN delivered_orders = 1 THEN '1 order'
               WHEN delivered_orders = 2 THEN '2 orders'
               WHEN delivered_orders = 3 THEN '3 orders'
               WHEN delivered_orders = 4 THEN '4 orders'
               ELSE '5+ orders'
           END AS purchase_frequency_bucket,
           CASE
               WHEN delivered_orders = 1 THEN 1
               WHEN delivered_orders = 2 THEN 2
               WHEN delivered_orders = 3 THEN 3
               WHEN delivered_orders = 4 THEN 4
               ELSE 5
           END AS bucket_sort,
           COUNT(*) AS customer_count
    FROM customer_summary
    GROUP BY purchase_frequency_bucket, bucket_sort
)
SELECT purchase_frequency_bucket,
       customer_count,
       ROUND(100.0 * customer_count / NULLIF(SUM(customer_count) OVER (), 0), 2)
           AS percentage_of_delivered_customers
FROM frequency_buckets
ORDER BY bucket_sort;

-- ============================================================================
-- SECTION B: CUSTOMER VALUE
-- ============================================================================

-- Business question 6: Which 20 customers have the highest delivered revenue?
-- Revenue and order count are aggregated at customer grain before ranking.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
)
SELECT customer_unique_id,
       delivered_orders,
       total_revenue,
       total_revenue / NULLIF(delivered_orders, 0) AS average_order_value,
       first_purchase_date,
       last_purchase_date
FROM customer_summary
ORDER BY total_revenue DESC, customer_unique_id
LIMIT 20;

-- Business question 7: Which 20 customers have the most delivered orders?
-- Revenue is included as context; no customer names or segments are inferred.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
)
SELECT customer_unique_id,
       delivered_orders,
       total_revenue,
       first_purchase_date,
       last_purchase_date
FROM customer_summary
ORDER BY delivered_orders DESC, total_revenue DESC, customer_unique_id
LIMIT 20;

-- Business question 8: What is the distribution of delivered customer revenue?
-- Median uses row numbers and averages the middle one or two customer values.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
),
ranked_customer_revenue AS (
    SELECT total_revenue,
           ROW_NUMBER() OVER (ORDER BY total_revenue, customer_unique_id)
               AS revenue_rank,
           COUNT(*) OVER () AS delivered_customer_count
    FROM customer_summary
)
SELECT MIN(total_revenue) AS minimum_customer_revenue,
       AVG(total_revenue) AS average_customer_revenue,
       AVG(CASE
               WHEN revenue_rank IN (
                   FLOOR((delivered_customer_count + 1) / 2),
                   FLOOR((delivered_customer_count + 2) / 2)
               )
               THEN total_revenue
           END) AS median_customer_revenue,
       MAX(total_revenue) AS maximum_customer_revenue,
       MAX(delivered_customer_count) AS delivered_customer_count
FROM ranked_customer_revenue;

-- ============================================================================
-- SECTION C: NEW VERSUS REPEAT CUSTOMERS OVER TIME
-- ============================================================================

-- Business questions 9-13: By purchase month, how many customers made a first
-- delivered purchase or a later delivered purchase, and what revenue belongs
-- to each class? A stable order_id tie-break assigns exactly one first order
-- when timestamps tie. A customer with multiple purchases in one month can be
-- counted as both new and repeat in that month because the orders differ.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
ranked_customer_purchases AS (
    SELECT customer_unique_id,
           order_id,
           order_purchase_timestamp,
           DATE(order_purchase_timestamp) AS purchase_date,
           DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
           order_revenue,
           MIN(DATE(order_purchase_timestamp)) OVER (
               PARTITION BY customer_unique_id
           ) AS first_purchase_date,
           ROW_NUMBER() OVER (
               PARTITION BY customer_unique_id
               ORDER BY order_purchase_timestamp, order_id
           ) AS purchase_number
    FROM delivered_order_rows
),
monthly_customer_purchase_metrics AS (
    SELECT purchase_month,
           COUNT(DISTINCT CASE
               WHEN purchase_number = 1 AND purchase_date = first_purchase_date
               THEN customer_unique_id
           END) AS new_customers,
           COUNT(DISTINCT CASE
               WHEN purchase_number > 1 THEN customer_unique_id
           END) AS repeat_customers,
           SUM(CASE
               WHEN purchase_number = 1 AND purchase_date = first_purchase_date
               THEN order_revenue ELSE 0.00
           END) AS new_customer_revenue,
           SUM(CASE
               WHEN purchase_number > 1 THEN order_revenue ELSE 0.00
           END) AS repeat_customer_revenue,
           SUM(order_revenue) AS monthly_delivered_revenue
    FROM ranked_customer_purchases
    GROUP BY purchase_month
)
SELECT purchase_month AS month,
       new_customers,
       repeat_customers,
       new_customer_revenue,
       repeat_customer_revenue,
       monthly_delivered_revenue,
       ROUND(
           100.0 * repeat_customer_revenue
           / NULLIF(monthly_delivered_revenue, 0),
           2
       ) AS repeat_customer_revenue_pct
FROM monthly_customer_purchase_metrics
ORDER BY month;

-- ============================================================================
-- SECTION D: TIME BETWEEN DELIVERED PURCHASES
-- ============================================================================

-- Business questions 14-15: What are the average and median intervals between
-- consecutive delivered purchases? LAG works at order grain within each
-- customer. days_between_orders is a calendar-day difference, so same-day
-- purchases have an interval of zero.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
ordered_customer_purchases AS (
    SELECT customer_unique_id,
           order_id,
           DATE(order_purchase_timestamp) AS current_order_date,
           LAG(DATE(order_purchase_timestamp)) OVER (
               PARTITION BY customer_unique_id
               ORDER BY order_purchase_timestamp, order_id
           ) AS previous_order_date
    FROM delivered_order_rows
),
purchase_intervals AS (
    SELECT customer_unique_id,
           previous_order_date,
           current_order_date,
           DATEDIFF(current_order_date, previous_order_date)
               AS days_between_orders
    FROM ordered_customer_purchases
    WHERE previous_order_date IS NOT NULL
),
ranked_intervals AS (
    SELECT days_between_orders,
           ROW_NUMBER() OVER (ORDER BY days_between_orders)
               AS interval_rank,
           COUNT(*) OVER () AS interval_count
    FROM purchase_intervals
)
SELECT AVG(days_between_orders) AS average_days_between_purchases,
       AVG(CASE
               WHEN interval_rank IN (
                   FLOOR((interval_count + 1) / 2),
                   FLOOR((interval_count + 2) / 2)
               )
               THEN days_between_orders
           END) AS median_days_between_purchases,
       MAX(interval_count) AS repeat_purchase_interval_count
FROM ranked_intervals;

-- Business question 16: How are repeat-purchase intervals distributed?
-- These descriptive intervals are not churn or inactivity thresholds.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
ordered_customer_purchases AS (
    SELECT customer_unique_id,
           order_id,
           DATE(order_purchase_timestamp) AS current_order_date,
           LAG(DATE(order_purchase_timestamp)) OVER (
               PARTITION BY customer_unique_id
               ORDER BY order_purchase_timestamp, order_id
           ) AS previous_order_date
    FROM delivered_order_rows
),
purchase_intervals AS (
    SELECT DATEDIFF(current_order_date, previous_order_date)
               AS days_between_orders
    FROM ordered_customer_purchases
    WHERE previous_order_date IS NOT NULL
),
interval_buckets AS (
    SELECT CASE
               WHEN days_between_orders BETWEEN 0 AND 30 THEN '0-30 days'
               WHEN days_between_orders BETWEEN 31 AND 60 THEN '31-60 days'
               WHEN days_between_orders BETWEEN 61 AND 90 THEN '61-90 days'
               WHEN days_between_orders BETWEEN 91 AND 180 THEN '91-180 days'
               ELSE '181+ days'
           END AS interval_bucket,
           CASE
               WHEN days_between_orders BETWEEN 0 AND 30 THEN 1
               WHEN days_between_orders BETWEEN 31 AND 60 THEN 2
               WHEN days_between_orders BETWEEN 61 AND 90 THEN 3
               WHEN days_between_orders BETWEEN 91 AND 180 THEN 4
               ELSE 5
           END AS bucket_sort,
           COUNT(*) AS interval_count
    FROM purchase_intervals
    GROUP BY interval_bucket, bucket_sort
)
SELECT interval_bucket,
       interval_count,
       ROUND(100.0 * interval_count / NULLIF(SUM(interval_count) OVER (), 0), 2)
           AS percentage_of_repeat_purchase_intervals
FROM interval_buckets
ORDER BY bucket_sort;

-- ============================================================================
-- SECTION E: CUSTOMER STATE BEHAVIOUR
-- ============================================================================

-- Business questions 17-19: What are repeat-customer rate, average delivered
-- orders, and average delivered revenue by state? To keep each customer in one
-- state group, assign the state recorded on their earliest delivered order;
-- order_id breaks timestamp ties. No minimum-size threshold is applied because
-- this is a descriptive table, not a ranked state comparison.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           c.customer_state,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
ranked_delivered_orders AS (
    SELECT customer_unique_id,
           customer_state,
           order_id,
           order_purchase_timestamp,
           order_revenue,
           ROW_NUMBER() OVER (
               PARTITION BY customer_unique_id
               ORDER BY order_purchase_timestamp, order_id
           ) AS purchase_number
    FROM delivered_order_rows
),
customer_summary AS (
    SELECT customer_unique_id,
           MAX(CASE WHEN purchase_number = 1 THEN customer_state END)
               AS assigned_customer_state,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM ranked_delivered_orders
    GROUP BY customer_unique_id
)
SELECT assigned_customer_state AS customer_state,
       COUNT(*) AS unique_delivered_customers,
       COUNT(CASE WHEN delivered_orders >= 2 THEN 1 END) AS repeat_customers,
       ROUND(
           100.0 * COUNT(CASE WHEN delivered_orders >= 2 THEN 1 END)
           / NULLIF(COUNT(*), 0),
           2
       ) AS repeat_customer_rate_pct,
       AVG(delivered_orders) AS average_delivered_orders_per_customer,
       AVG(total_revenue) AS average_delivered_revenue_per_customer
FROM customer_summary
GROUP BY assigned_customer_state
ORDER BY assigned_customer_state;

-- ============================================================================
-- SECTION F: CUSTOMER CATEGORY BREADTH
-- ============================================================================

-- Business question 20: How many distinct product categories has each customer
-- purchased from through delivered orders? Count distinct source category names;
-- NULL category values are excluded rather than merged into a made-up category.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
),
customer_category_breadth AS (
    SELECT dor.customer_unique_id,
           COUNT(DISTINCT p.product_category_name) AS distinct_categories
    FROM delivered_order_rows AS dor
    LEFT JOIN order_items AS oi
        ON oi.order_id = dor.order_id
    LEFT JOIN products AS p
        ON p.product_id = oi.product_id
    GROUP BY dor.customer_unique_id
)
SELECT cs.customer_unique_id,
       cs.delivered_orders,
       COALESCE(ccb.distinct_categories, 0) AS distinct_categories
FROM customer_summary AS cs
LEFT JOIN customer_category_breadth AS ccb
    ON ccb.customer_unique_id = cs.customer_unique_id
ORDER BY distinct_categories DESC, cs.customer_unique_id;

-- Business question 21: How do one-time and repeat delivered customers compare
-- on category breadth, revenue, and order count? This is descriptive and does
-- not imply that category breadth causes purchasing frequency or revenue.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
),
customer_category_breadth AS (
    SELECT dor.customer_unique_id,
           COUNT(DISTINCT p.product_category_name) AS distinct_categories
    FROM delivered_order_rows AS dor
    LEFT JOIN order_items AS oi
        ON oi.order_id = dor.order_id
    LEFT JOIN products AS p
        ON p.product_id = oi.product_id
    GROUP BY dor.customer_unique_id
)
SELECT CASE
           WHEN cs.delivered_orders = 1 THEN 'One-time customer'
           ELSE 'Repeat customer'
       END AS purchase_frequency_group,
       COUNT(*) AS customer_count,
       AVG(COALESCE(ccb.distinct_categories, 0))
           AS average_distinct_categories,
       AVG(cs.total_revenue) AS average_delivered_revenue,
       AVG(cs.delivered_orders) AS average_delivered_order_count
FROM customer_summary AS cs
LEFT JOIN customer_category_breadth AS ccb
    ON ccb.customer_unique_id = cs.customer_unique_id
GROUP BY purchase_frequency_group
ORDER BY MIN(cs.delivered_orders);

-- ============================================================================
-- SECTION G: CUSTOMER REVENUE CONCENTRATION
-- ============================================================================

-- Business question 22: What shares of delivered revenue come from the top 1%,
-- 5%, and 10% of delivered customers? ROW_NUMBER plus customer_unique_id as a
-- tie-break selects exactly CEIL(percent * customer_count) customers, even when
-- revenue ties occur. Percentages use total revenue across all delivered
-- customers as the denominator; zero-revenue customers remain in the ranking.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
),
ranked_customer_revenue AS (
    SELECT customer_unique_id,
           total_revenue,
           ROW_NUMBER() OVER (
               ORDER BY total_revenue DESC, customer_unique_id
           ) AS customer_rank,
           COUNT(*) OVER () AS customer_count,
           SUM(total_revenue) OVER () AS all_customer_revenue
    FROM customer_summary
),
concentration_totals AS (
    SELECT MAX(customer_count) AS customer_count,
           MAX(all_customer_revenue) AS all_customer_revenue,
           CEIL(MAX(customer_count) * 0.01) AS top_1_customer_count,
           CEIL(MAX(customer_count) * 0.05) AS top_5_customer_count,
           CEIL(MAX(customer_count) * 0.10) AS top_10_customer_count,
           SUM(CASE WHEN customer_rank <= CEIL(customer_count * 0.01)
                    THEN total_revenue ELSE 0.00 END) AS top_1_revenue,
           SUM(CASE WHEN customer_rank <= CEIL(customer_count * 0.05)
                    THEN total_revenue ELSE 0.00 END) AS top_5_revenue,
           SUM(CASE WHEN customer_rank <= CEIL(customer_count * 0.10)
                    THEN total_revenue ELSE 0.00 END) AS top_10_revenue
    FROM ranked_customer_revenue
)
SELECT customer_count AS delivered_customer_count,
       all_customer_revenue AS total_delivered_customer_revenue,
       top_1_customer_count,
       top_1_revenue,
       ROUND(100.0 * top_1_revenue / NULLIF(all_customer_revenue, 0), 2)
           AS top_1_customer_revenue_share_pct,
       top_5_customer_count,
       top_5_revenue,
       ROUND(100.0 * top_5_revenue / NULLIF(all_customer_revenue, 0), 2)
           AS top_5_customer_revenue_share_pct,
       top_10_customer_count,
       top_10_revenue,
       ROUND(100.0 * top_10_revenue / NULLIF(all_customer_revenue, 0), 2)
           AS top_10_customer_revenue_share_pct
FROM concentration_totals;

-- Business question 23: What is each customer's cumulative contribution to
-- delivered revenue? One row per customer, ranked by revenue descending with
-- customer_unique_id as a stable tie-break, suitable for a later Pareto chart.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
)
SELECT customer_unique_id,
       ROW_NUMBER() OVER (
           ORDER BY total_revenue DESC, customer_unique_id
       ) AS customer_revenue_rank,
       total_revenue AS customer_revenue,
       SUM(total_revenue) OVER (
           ORDER BY total_revenue DESC, customer_unique_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_customer_revenue,
       SUM(total_revenue) OVER () AS total_delivered_revenue,
       ROUND(
           100.0 * SUM(total_revenue) OVER (
               ORDER BY total_revenue DESC, customer_unique_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) / NULLIF(SUM(total_revenue) OVER (), 0),
           2
       ) AS cumulative_revenue_contribution_pct
FROM customer_summary
ORDER BY total_revenue DESC, customer_unique_id;

-- ============================================================================
-- SECTION H: OBSERVED CUSTOMER RECENCY
-- ============================================================================

-- Business question: How many calendar days have elapsed since each customer's
-- last delivered purchase, relative to the latest delivered purchase date in
-- this dataset? Bands are observational recency only, not churn labels.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
),
latest_observed_purchase AS (
    SELECT MAX(DATE(order_purchase_timestamp)) AS max_delivered_purchase_date
    FROM orders
    WHERE order_status = 'delivered'
),
customer_recency AS (
    SELECT cs.customer_unique_id,
           cs.last_purchase_date,
           lop.max_delivered_purchase_date,
           DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
               AS days_since_last_purchase,
           CASE
               WHEN DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
                    BETWEEN 0 AND 30 THEN '0-30 days'
               WHEN DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
                    BETWEEN 31 AND 60 THEN '31-60 days'
               WHEN DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
                    BETWEEN 61 AND 90 THEN '61-90 days'
               WHEN DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
                    BETWEEN 91 AND 180 THEN '91-180 days'
               ELSE '181+ days'
           END AS recency_band,
           CASE
               WHEN DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
                    BETWEEN 0 AND 30 THEN 1
               WHEN DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
                    BETWEEN 31 AND 60 THEN 2
               WHEN DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
                    BETWEEN 61 AND 90 THEN 3
               WHEN DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
                    BETWEEN 91 AND 180 THEN 4
               ELSE 5
           END AS band_sort
    FROM customer_summary AS cs
    CROSS JOIN latest_observed_purchase AS lop
)
SELECT customer_unique_id,
       last_purchase_date,
       max_delivered_purchase_date,
       days_since_last_purchase,
       recency_band
FROM customer_recency
ORDER BY band_sort, days_since_last_purchase DESC, customer_unique_id;

-- Optional observational summary: how many delivered customers fall in each
-- recency band? It uses the same dataset-relative reference date, not today's
-- date; the source is historical and incomplete outside its observation window.
WITH delivered_order_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           o.order_purchase_timestamp,
           c.customer_unique_id,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_order_item_revenue AS oir
        ON oir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
customer_summary AS (
    SELECT customer_unique_id,
           COUNT(*) AS delivered_orders,
           SUM(order_revenue) AS total_revenue,
           MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date,
           DATEDIFF(
               MAX(DATE(order_purchase_timestamp)),
               MIN(DATE(order_purchase_timestamp))
           ) AS active_span_days
    FROM delivered_order_rows
    GROUP BY customer_unique_id
),
latest_observed_purchase AS (
    SELECT MAX(DATE(order_purchase_timestamp)) AS max_delivered_purchase_date
    FROM orders
    WHERE order_status = 'delivered'
),
customer_recency AS (
    SELECT cs.customer_unique_id,
           DATEDIFF(lop.max_delivered_purchase_date, cs.last_purchase_date)
               AS days_since_last_purchase
    FROM customer_summary AS cs
    CROSS JOIN latest_observed_purchase AS lop
),
recency_bands AS (
    SELECT CASE
               WHEN days_since_last_purchase BETWEEN 0 AND 30 THEN '0-30 days'
               WHEN days_since_last_purchase BETWEEN 31 AND 60 THEN '31-60 days'
               WHEN days_since_last_purchase BETWEEN 61 AND 90 THEN '61-90 days'
               WHEN days_since_last_purchase BETWEEN 91 AND 180 THEN '91-180 days'
               ELSE '181+ days'
           END AS recency_band,
           CASE
               WHEN days_since_last_purchase BETWEEN 0 AND 30 THEN 1
               WHEN days_since_last_purchase BETWEEN 31 AND 60 THEN 2
               WHEN days_since_last_purchase BETWEEN 61 AND 90 THEN 3
               WHEN days_since_last_purchase BETWEEN 91 AND 180 THEN 4
               ELSE 5
           END AS band_sort,
           COUNT(*) AS customer_count
    FROM customer_recency
    GROUP BY recency_band, band_sort
)
SELECT recency_band,
       customer_count,
       ROUND(100.0 * customer_count / NULLIF(SUM(customer_count) OVER (), 0), 2)
           AS percentage_of_delivered_customers
FROM recency_bands
ORDER BY band_sort;

-- ============================================================================
-- INTERVIEW CONCEPTS DEMONSTRATED
-- ============================================================================
-- Customer-level grain; repeat-purchase logic; first-purchase identification;
-- window functions; LAG; customer ranking; percentage contribution; cumulative
-- revenue; recency analysis; distinct counting; and defensive aggregation.
