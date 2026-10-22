-- RetailPulse Phase 6: foundational SQL analysis (MySQL 8).
-- Revenue in this file is delivered item price: SUM(order_items.price).
-- It excludes freight, non-delivered orders, payment amounts, and profit/cost.
-- Each query is standalone and can be run independently.

USE retailpulse;

-- ============================================================================
-- SECTION A: ORDER OVERVIEW
-- ============================================================================

-- Business question 1: How many orders exist for each status, and what share
-- of all orders does each status represent? The denominator is all orders.
WITH status_counts AS (
    SELECT order_status, COUNT(*) AS order_count
    FROM orders
    GROUP BY order_status
),
total_orders AS (
    SELECT COUNT(*) AS total_order_count
    FROM orders
)
SELECT sc.order_status,
       sc.order_count,
       ROUND(100.0 * sc.order_count / NULLIF(t.total_order_count, 0), 2)
           AS percentage_of_orders
FROM status_counts AS sc
CROSS JOIN total_orders AS t
ORDER BY sc.order_status;

-- Business question 2: How many total orders exist across all statuses?
SELECT COUNT(*) AS total_orders
FROM orders;

-- Business question 3: How many delivered orders exist?
SELECT COUNT(*) AS delivered_orders
FROM orders
WHERE order_status = 'delivered';

-- Business question 4: What percentage of all orders were delivered?
SELECT COUNT(CASE WHEN order_status = 'delivered' THEN 1 END)
           AS delivered_orders,
       COUNT(*) AS total_orders,
       ROUND(
           100.0 * COUNT(CASE WHEN order_status = 'delivered' THEN 1 END)
           / NULLIF(COUNT(*), 0),
           2
       ) AS delivered_order_percentage
FROM orders;

-- Business question 5: What purchase-date range is represented?
-- total_days_observed counts inclusive calendar days between the endpoint dates.
WITH purchase_range AS (
    SELECT MIN(DATE(order_purchase_timestamp)) AS first_purchase_date,
           MAX(DATE(order_purchase_timestamp)) AS last_purchase_date
    FROM orders
)
SELECT first_purchase_date,
       last_purchase_date,
       DATEDIFF(last_purchase_date, first_purchase_date) + 1
           AS total_days_observed
FROM purchase_range;

-- ============================================================================
-- SECTION B: CUSTOMER OVERVIEW
-- ============================================================================

-- Business question 6: How many source-defined unique customers exist?
-- customer_unique_id is the cross-order identity; customer_id is order-specific.
SELECT COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- Business question 7: How many source-defined unique customers placed at least
-- one delivered order? Join by customer_id, then count customer_unique_id.
SELECT COUNT(DISTINCT c.customer_unique_id) AS delivered_customers
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered';

-- Business question 8: How many unique customers are associated with each
-- customer-record state? This includes all order statuses, not just delivered.
SELECT c.customer_state,
       COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM customers AS c
GROUP BY c.customer_state
ORDER BY c.customer_state;

-- ============================================================================
-- SECTION C: DELIVERED ITEM-PRICE REVENUE FOUNDATION
-- ============================================================================

-- Business question 9: What is total delivered item-price revenue?
-- Each order_items row contributes its price once; freight is excluded.
SELECT SUM(oi.price) AS total_delivered_item_revenue
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- Business question 10: How many delivered item lines were recorded?
-- There is no quantity column: this counts rows/lines, not verified physical units.
SELECT COUNT(*) AS delivered_item_lines
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- Business question 11: What is the average item-line price for delivered orders?
SELECT AVG(oi.price) AS average_delivered_item_price
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- Business question 12: What are the minimum and maximum delivered item prices?
SELECT MIN(oi.price) AS minimum_delivered_item_price,
       MAX(oi.price) AS maximum_delivered_item_price
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- ============================================================================
-- SECTION D: DELIVERED ORDER-LEVEL REVENUE
-- ============================================================================

-- Business questions 13-14: What are AOV, median order revenue, and the minimum
-- and maximum order revenues? First aggregate item prices to one row per order;
-- do not average item rows. The median is the middle value, or mean of the two
-- middle values when the delivered-order count is even.
WITH delivered_order_revenue AS (
    SELECT o.order_id,
           COALESCE(SUM(oi.price), 0.00) AS order_revenue
    FROM orders AS o
    LEFT JOIN order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
),
ranked_order_revenue AS (
    SELECT order_revenue,
           ROW_NUMBER() OVER (ORDER BY order_revenue, order_id) AS revenue_rank,
           COUNT(*) OVER () AS delivered_order_count
    FROM delivered_order_revenue
)
SELECT AVG(order_revenue) AS average_order_value,
       AVG(CASE
               WHEN revenue_rank IN (
                   FLOOR((delivered_order_count + 1) / 2),
                   FLOOR((delivered_order_count + 2) / 2)
               )
               THEN order_revenue
           END) AS median_order_revenue,
       MIN(order_revenue) AS minimum_order_revenue,
       MAX(order_revenue) AS maximum_order_revenue,
       MAX(delivered_order_count) AS delivered_orders_in_revenue_set
FROM ranked_order_revenue;

-- ============================================================================
-- SECTION E: MONTHLY DELIVERED REVENUE
-- ============================================================================

-- Business questions 15-17: What are delivered revenue, delivered order count,
-- and unique customers by purchase month? Revenue is first summed to order
-- grain. Empty calendar months are returned with zero counts and revenue.
-- Month is based on purchase timestamp.
WITH RECURSIVE date_bounds AS (
    SELECT CAST(DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m-01') AS DATE)
               AS first_month,
           CAST(DATE_FORMAT(MAX(order_purchase_timestamp), '%Y-%m-01') AS DATE)
               AS last_month
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
           c.customer_unique_id,
           COALESCE(dir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_item_revenue AS dir
        ON dir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
monthly_metrics AS (
    SELECT month,
           SUM(order_revenue) AS monthly_revenue,
           COUNT(DISTINCT order_id) AS delivered_orders,
           COUNT(DISTINCT customer_unique_id) AS unique_customers
    FROM delivered_order_rows
    GROUP BY month
),
month_calendar (month_start) AS (
    SELECT first_month
    FROM date_bounds
    WHERE first_month IS NOT NULL
    UNION ALL
    SELECT DATE_ADD(mc.month_start, INTERVAL 1 MONTH)
    FROM month_calendar AS mc
    JOIN date_bounds AS bounds
        ON mc.month_start < bounds.last_month
)
SELECT DATE_FORMAT(mc.month_start, '%Y-%m') AS month,
       COALESCE(mm.monthly_revenue, 0.00) AS monthly_revenue,
       COALESCE(mm.delivered_orders, 0) AS delivered_orders,
       COALESCE(mm.unique_customers, 0) AS unique_customers
FROM month_calendar AS mc
LEFT JOIN monthly_metrics AS mm
    ON mm.month = DATE_FORMAT(mc.month_start, '%Y-%m')
ORDER BY mc.month_start;

-- ============================================================================
-- SECTION F: MONTH-OVER-MONTH REVENUE CHANGE
-- ============================================================================

-- Business question: How did delivered item-price revenue change month over
-- month? Empty calendar months are included at zero so LAG compares adjacent
-- calendar months. The first month is NULL; zero previous revenue also returns
-- NULL growth through NULLIF rather than an invented percentage.
WITH RECURSIVE date_bounds AS (
    SELECT CAST(DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m-01') AS DATE)
               AS first_month,
           CAST(DATE_FORMAT(MAX(order_purchase_timestamp), '%Y-%m-01') AS DATE)
               AS last_month
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
),
delivered_order_rows AS (
    SELECT o.order_id,
           DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
           COALESCE(dir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    LEFT JOIN delivered_item_revenue AS dir
        ON dir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),
monthly_revenue AS (
    SELECT month,
           SUM(order_revenue) AS monthly_revenue
    FROM delivered_order_rows
    GROUP BY month
),
month_calendar (month_start) AS (
    SELECT first_month
    FROM date_bounds
    WHERE first_month IS NOT NULL
    UNION ALL
    SELECT DATE_ADD(mc.month_start, INTERVAL 1 MONTH)
    FROM month_calendar AS mc
    JOIN date_bounds AS bounds
        ON mc.month_start < bounds.last_month
),
complete_monthly_revenue AS (
    SELECT DATE_FORMAT(mc.month_start, '%Y-%m') AS month,
           COALESCE(mr.monthly_revenue, 0.00) AS monthly_revenue
    FROM month_calendar AS mc
    LEFT JOIN monthly_revenue AS mr
        ON mr.month = DATE_FORMAT(mc.month_start, '%Y-%m')
),
revenue_with_previous_month AS (
    SELECT month,
           monthly_revenue,
           LAG(monthly_revenue) OVER (ORDER BY month) AS previous_month_revenue
    FROM complete_monthly_revenue
)
SELECT month,
       monthly_revenue,
       previous_month_revenue,
       monthly_revenue - previous_month_revenue AS revenue_change,
       100.0 * (monthly_revenue - previous_month_revenue)
           / NULLIF(previous_month_revenue, 0) AS month_over_month_growth_pct
FROM revenue_with_previous_month
ORDER BY month;

-- ============================================================================
-- SECTION G: DELIVERED PRODUCT-CATEGORY ANALYSIS
-- ============================================================================

-- Business question 18: What are delivered item-price revenue and sales counts
-- by category? LEFT JOIN preserves categories without a translation. Order
-- count is distinct because a category can have multiple item lines per order.
WITH delivered_category_lines AS (
    SELECT oi.order_id,
           oi.price,
           COALESCE(
               pct.product_category_name_english,
               p.product_category_name,
               'Unknown'
           ) AS category
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON p.product_id = oi.product_id
    LEFT JOIN product_category_translations AS pct
        ON pct.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
),
category_summary AS (
    SELECT category,
           SUM(price) AS revenue,
           COUNT(DISTINCT order_id) AS order_count,
           COUNT(*) AS item_count
    FROM delivered_category_lines
    GROUP BY category
)
SELECT category,
       revenue,
       order_count,
       item_count,
       ROUND(100.0 * revenue / NULLIF(SUM(revenue) OVER (), 0), 2)
           AS percentage_of_total_revenue
FROM category_summary
ORDER BY revenue DESC, category;

-- Business question 19: Which ten categories have the highest delivered
-- revenue? Counts retain their category-level grains.
WITH delivered_category_lines AS (
    SELECT oi.order_id,
           oi.price,
           COALESCE(
               pct.product_category_name_english,
               p.product_category_name,
               'Unknown'
           ) AS category
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON p.product_id = oi.product_id
    LEFT JOIN product_category_translations AS pct
        ON pct.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
)
SELECT category,
       SUM(price) AS revenue,
       COUNT(DISTINCT order_id) AS order_count,
       COUNT(*) AS item_count
FROM delivered_category_lines
GROUP BY category
ORDER BY revenue DESC, category
LIMIT 10;

-- Business question 20: Which categories have the lowest delivered revenue?
-- These are categories with delivered sales, not a judgment of performance;
-- small item/order counts need context before comparison.
WITH delivered_category_lines AS (
    SELECT oi.order_id,
           oi.price,
           COALESCE(
               pct.product_category_name_english,
               p.product_category_name,
               'Unknown'
           ) AS category
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON p.product_id = oi.product_id
    LEFT JOIN product_category_translations AS pct
        ON pct.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
)
SELECT category,
       SUM(price) AS revenue,
       COUNT(DISTINCT order_id) AS order_count,
       COUNT(*) AS item_count
FROM delivered_category_lines
GROUP BY category
ORDER BY revenue ASC, category
LIMIT 10;

-- ============================================================================
-- SECTION H: DELIVERED PRODUCT ANALYSIS
-- ============================================================================

-- Business question 21: Which ten products have the highest delivered revenue?
-- Product names are not present in the schema; category is shown as context.
WITH delivered_product_lines AS (
    SELECT oi.order_id,
           oi.product_id,
           oi.price,
           COALESCE(
               pct.product_category_name_english,
               p.product_category_name,
               'Unknown'
           ) AS category
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON p.product_id = oi.product_id
    LEFT JOIN product_category_translations AS pct
        ON pct.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
)
SELECT product_id,
       category,
       SUM(price) AS revenue,
       COUNT(DISTINCT order_id) AS orders_containing_product,
       COUNT(*) AS item_count,
       AVG(price) AS average_item_price
FROM delivered_product_lines
GROUP BY product_id, category
ORDER BY revenue DESC, product_id
LIMIT 10;

-- Business question 22: Which ten products occur in the greatest number of
-- delivered orders? Order count is distinct at order-product grain.
WITH delivered_product_lines AS (
    SELECT oi.order_id,
           oi.product_id,
           COALESCE(
               pct.product_category_name_english,
               p.product_category_name,
               'Unknown'
           ) AS category
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON p.product_id = oi.product_id
    LEFT JOIN product_category_translations AS pct
        ON pct.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
)
SELECT product_id,
       category,
       COUNT(DISTINCT order_id) AS orders_containing_product
FROM delivered_product_lines
GROUP BY product_id, category
ORDER BY orders_containing_product DESC, product_id
LIMIT 10;

-- ============================================================================
-- SECTION I: DELIVERED CUSTOMER-STATE ANALYSIS
-- ============================================================================

-- Business question 23: What are delivered revenue, orders, unique customers,
-- and AOV by customer state? Item prices are first aggregated to order grain,
-- preventing item rows from weighting the order-level AOV incorrectly.
WITH delivered_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
),
delivered_order_state AS (
    SELECT o.order_id,
           c.customer_state,
           c.customer_unique_id,
           COALESCE(dir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_item_revenue AS dir
        ON dir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
)
SELECT customer_state,
       SUM(order_revenue) AS revenue,
       COUNT(*) AS delivered_orders,
       COUNT(DISTINCT customer_unique_id) AS unique_customers,
       AVG(order_revenue) AS average_order_value
FROM delivered_order_state
GROUP BY customer_state
ORDER BY revenue DESC, customer_state;

-- Business question 24: Which customer states have the highest delivered
-- revenue? AOV remains an average over one row per delivered order.
WITH delivered_item_revenue AS (
    SELECT oi.order_id,
           SUM(oi.price) AS order_revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
),
delivered_order_state AS (
    SELECT o.order_id,
           c.customer_state,
           c.customer_unique_id,
           COALESCE(dir.order_revenue, 0.00) AS order_revenue
    FROM orders AS o
    JOIN customers AS c
        ON c.customer_id = o.customer_id
    LEFT JOIN delivered_item_revenue AS dir
        ON dir.order_id = o.order_id
    WHERE o.order_status = 'delivered'
)
SELECT customer_state,
       SUM(order_revenue) AS revenue,
       COUNT(*) AS delivered_orders,
       COUNT(DISTINCT customer_unique_id) AS unique_customers,
       AVG(order_revenue) AS average_order_value
FROM delivered_order_state
GROUP BY customer_state
ORDER BY revenue DESC, customer_state
LIMIT 10;

-- Business question 25: How many delivered orders are associated with each
-- customer state? Count order-header rows without joining item lines.
SELECT c.customer_state,
       COUNT(*) AS delivered_order_count
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY delivered_order_count DESC, c.customer_state;

-- ============================================================================
-- INTERVIEW CONCEPTS DEMONSTRATED
-- ============================================================================
-- Filtering; joins; aggregation; GROUP BY; COUNT DISTINCT; CTEs; window
-- functions; LAG; NULL handling; COALESCE; percentage calculations; defensive
-- division; chronological ordering; and grain management.
