-- RetailPulse Phase 8: cohort and retention analysis (MySQL 8).
-- Customer identity: customer_unique_id. Completed-purchase population: delivered orders.
-- Cohort month is the calendar month of each customer's first delivered purchase.
-- Revenue is SUM(order_items.price) for delivered orders; freight/payments are excluded.
-- Every statement is standalone because MySQL CTEs have statement scope.
-- This script is read-only: it contains SELECT statements and USE only.
USE retailpulse;

-- ============================================================================
-- SECTION A-C: CUSTOMER COHORTS AND COHORT SIZE
-- ============================================================================
-- Question 1: How many distinct delivered customers belong to each first-purchase month?
-- Cohort month is the first day of that calendar month. MIN(purchase_date) finds
-- the exact first date; MIN(purchase_month) is its corresponding cohort month.
WITH delivered_orders AS (
    SELECT o.order_id, c.customer_unique_id,
           DATE(o.order_purchase_timestamp) AS purchase_date,
           DATE_SUB(DATE(o.order_purchase_timestamp),
               INTERVAL DAYOFMONTH(o.order_purchase_timestamp) - 1 DAY) AS purchase_month
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT customer_unique_id,
           MIN(purchase_date) AS first_purchase_date,
           MIN(purchase_month) AS cohort_month
    FROM delivered_orders
    GROUP BY customer_unique_id
)
SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
FROM customer_cohorts
GROUP BY cohort_month
ORDER BY cohort_month;

-- ============================================================================
-- SECTION B,D: CUSTOMER ACTIVITY MONTH AND RETENTION COUNTS
-- ============================================================================
-- Question 2: How many cohort customers purchased in each elapsed month?
-- DISTINCT at customer-month grain prevents multiple monthly orders counting twice.
-- TIMESTAMPDIFF on first-of-month dates gives 0 for cohort month, 1 for next month.
WITH delivered_orders AS (
    SELECT o.order_id, c.customer_unique_id,
           DATE_SUB(DATE(o.order_purchase_timestamp),
               INTERVAL DAYOFMONTH(o.order_purchase_timestamp) - 1 DAY) AS purchase_month
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM delivered_orders GROUP BY customer_unique_id
),
customer_month_activity AS (
    SELECT DISTINCT d.customer_unique_id, cc.cohort_month, d.purchase_month,
           TIMESTAMPDIFF(MONTH, cc.cohort_month, d.purchase_month)
               AS months_since_first_purchase
    FROM delivered_orders AS d
    JOIN customer_cohorts AS cc ON cc.customer_unique_id = d.customer_unique_id
)
SELECT cohort_month, months_since_first_purchase,
       COUNT(DISTINCT customer_unique_id) AS active_customers
FROM customer_month_activity
GROUP BY cohort_month, months_since_first_purchase
ORDER BY cohort_month, months_since_first_purchase;

-- ============================================================================
-- SECTION E: COHORT RETENTION RATE
-- ============================================================================
-- Retention percentage = active distinct cohort customers / original cohort size.
-- Month 0 should be 100% because every cohort member has a delivered purchase
-- in their first delivered purchase month. NULLIF protects an empty denominator.
WITH delivered_orders AS (
    SELECT o.order_id, c.customer_unique_id,
           DATE_SUB(DATE(o.order_purchase_timestamp),
               INTERVAL DAYOFMONTH(o.order_purchase_timestamp) - 1 DAY) AS purchase_month
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM delivered_orders GROUP BY customer_unique_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts GROUP BY cohort_month
),
customer_month_activity AS (
    SELECT DISTINCT d.customer_unique_id, cc.cohort_month, d.purchase_month,
           TIMESTAMPDIFF(MONTH, cc.cohort_month, d.purchase_month)
               AS months_since_first_purchase
    FROM delivered_orders AS d
    JOIN customer_cohorts AS cc ON cc.customer_unique_id = d.customer_unique_id
),
active_counts AS (
    SELECT cohort_month, months_since_first_purchase,
           COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM customer_month_activity
    GROUP BY cohort_month, months_since_first_purchase
)
SELECT ac.cohort_month, cs.cohort_size, ac.months_since_first_purchase,
       ac.active_customers,
       ROUND(100.0 * ac.active_customers / NULLIF(cs.cohort_size, 0), 2)
           AS retention_rate_pct
FROM active_counts AS ac JOIN cohort_sizes AS cs USING (cohort_month)
ORDER BY ac.cohort_month, ac.months_since_first_purchase;

-- ============================================================================
-- SECTION F: LONG-FORM RETENTION MATRIX DATASET
-- ============================================================================
-- Long format for later visualization; no month columns are pivoted in SQL.
-- This returns the same observed customer-month counts and rates as Section E.
WITH delivered_orders AS (
    SELECT o.order_id, c.customer_unique_id,
           DATE_SUB(DATE(o.order_purchase_timestamp),
               INTERVAL DAYOFMONTH(o.order_purchase_timestamp) - 1 DAY) AS purchase_month
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM delivered_orders GROUP BY customer_unique_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts GROUP BY cohort_month
),
customer_month_activity AS (
    SELECT DISTINCT d.customer_unique_id, cc.cohort_month, d.purchase_month,
           TIMESTAMPDIFF(MONTH, cc.cohort_month, d.purchase_month) AS month_number
    FROM delivered_orders AS d
    JOIN customer_cohorts AS cc ON cc.customer_unique_id = d.customer_unique_id
),
active_counts AS (
    SELECT cohort_month, month_number,
           COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM customer_month_activity GROUP BY cohort_month, month_number
)
SELECT ac.cohort_month, ac.month_number, ac.active_customers, cs.cohort_size,
       ROUND(100.0 * ac.active_customers / NULLIF(cs.cohort_size, 0), 2)
           AS retention_rate_pct
FROM active_counts AS ac JOIN cohort_sizes AS cs USING (cohort_month)
ORDER BY ac.cohort_month, ac.month_number;

-- ============================================================================
-- SECTION G-H: COHORT REVENUE AND REVENUE PER ORIGINAL COHORT CUSTOMER
-- ============================================================================
-- Questions 3: delivered item-price revenue by cohort and purchase month,
-- plus revenue per original cohort customer. Item lines are summed to order
-- grain before joining customer/cohort data, preventing item fanout of counts.
WITH delivered_orders AS (
    SELECT o.order_id, c.customer_unique_id,
           DATE_SUB(DATE(o.order_purchase_timestamp),
               INTERVAL DAYOFMONTH(o.order_purchase_timestamp) - 1 DAY) AS purchase_month
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM delivered_orders GROUP BY customer_unique_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts GROUP BY cohort_month
),
order_item_revenue AS (
    SELECT oi.order_id, SUM(oi.price) AS order_revenue
    FROM order_items AS oi GROUP BY oi.order_id
),
cohort_order_revenue AS (
    SELECT d.order_id, d.customer_unique_id, cc.cohort_month, d.purchase_month,
           TIMESTAMPDIFF(MONTH, cc.cohort_month, d.purchase_month) AS months_since_first_purchase,
           COALESCE(oir.order_revenue, 0.00) AS order_revenue
    FROM delivered_orders AS d
    JOIN customer_cohorts AS cc ON cc.customer_unique_id = d.customer_unique_id
    LEFT JOIN order_item_revenue AS oir ON oir.order_id = d.order_id
),
cohort_month_revenue AS (
    SELECT cohort_month, months_since_first_purchase, SUM(order_revenue) AS cohort_revenue
    FROM cohort_order_revenue
    GROUP BY cohort_month, months_since_first_purchase
)
SELECT cmr.cohort_month, cmr.months_since_first_purchase, cmr.cohort_revenue,
       cs.cohort_size,
       cmr.cohort_revenue / NULLIF(cs.cohort_size, 0)
           AS revenue_per_original_cohort_customer
FROM cohort_month_revenue AS cmr
JOIN cohort_sizes AS cs USING (cohort_month)
ORDER BY cmr.cohort_month, cmr.months_since_first_purchase;

-- ============================================================================
-- SECTION I: SECOND-PURCHASE TIMING
-- ============================================================================
-- Questions 4-5: average and median calendar days to the second delivered order.
-- The order_id tie-break makes same-timestamp purchase sequencing deterministic.
WITH delivered_order_dates AS (
    SELECT o.order_id, c.customer_unique_id, DATE(o.order_purchase_timestamp) AS purchase_date,
           o.order_purchase_timestamp
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
ranked_purchases AS (
    SELECT customer_unique_id, order_id, purchase_date,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
               ORDER BY order_purchase_timestamp, order_id) AS purchase_number,
           FIRST_VALUE(purchase_date) OVER (PARTITION BY customer_unique_id
               ORDER BY order_purchase_timestamp, order_id) AS first_purchase_date
    FROM delivered_order_dates
),
second_purchase_gaps AS (
    SELECT customer_unique_id, first_purchase_date, purchase_date AS second_purchase_date,
           DATEDIFF(purchase_date, first_purchase_date) AS days_to_second_purchase
    FROM ranked_purchases WHERE purchase_number = 2
),
ranked_gaps AS (
    SELECT days_to_second_purchase,
           ROW_NUMBER() OVER (ORDER BY days_to_second_purchase, customer_unique_id) AS gap_rank,
           COUNT(*) OVER () AS gap_count
    FROM second_purchase_gaps
)
SELECT COUNT(*) AS customers_with_second_purchase,
       AVG(days_to_second_purchase) AS average_days_to_second_purchase,
       AVG(CASE WHEN gap_rank IN (FLOOR((gap_count + 1) / 2), FLOOR((gap_count + 2) / 2))
                THEN days_to_second_purchase END) AS median_days_to_second_purchase
FROM ranked_gaps;

-- Question 6: distribution of observed days to second delivered purchase.
WITH delivered_order_dates AS (
    SELECT o.order_id, c.customer_unique_id, DATE(o.order_purchase_timestamp) AS purchase_date,
           o.order_purchase_timestamp
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
ranked_purchases AS (
    SELECT customer_unique_id, order_id, purchase_date,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
               ORDER BY order_purchase_timestamp, order_id) AS purchase_number,
           FIRST_VALUE(purchase_date) OVER (PARTITION BY customer_unique_id
               ORDER BY order_purchase_timestamp, order_id) AS first_purchase_date
    FROM delivered_order_dates
),
second_purchase_gaps AS (
    SELECT DATEDIFF(purchase_date, first_purchase_date) AS days_to_second_purchase
    FROM ranked_purchases WHERE purchase_number = 2
),
gap_buckets AS (
    SELECT CASE WHEN days_to_second_purchase BETWEEN 0 AND 30 THEN '0-30 days'
                WHEN days_to_second_purchase BETWEEN 31 AND 60 THEN '31-60 days'
                WHEN days_to_second_purchase BETWEEN 61 AND 90 THEN '61-90 days'
                WHEN days_to_second_purchase BETWEEN 91 AND 180 THEN '91-180 days'
                ELSE '181+ days' END AS days_to_second_purchase_band,
           CASE WHEN days_to_second_purchase BETWEEN 0 AND 30 THEN 1
                WHEN days_to_second_purchase BETWEEN 31 AND 60 THEN 2
                WHEN days_to_second_purchase BETWEEN 61 AND 90 THEN 3
                WHEN days_to_second_purchase BETWEEN 91 AND 180 THEN 4 ELSE 5 END AS band_order,
           COUNT(*) AS customer_count
    FROM second_purchase_gaps GROUP BY days_to_second_purchase_band, band_order
)
SELECT days_to_second_purchase_band, customer_count,
       ROUND(100.0 * customer_count / NULLIF(SUM(customer_count) OVER (), 0), 2)
           AS percentage_of_second_purchase_customers
FROM gap_buckets ORDER BY band_order;

-- ============================================================================
-- SECTION J: SECOND-PURCHASE RATE
-- ============================================================================
-- Question 7: customer-grain repeat-customer share. This definition matches
-- Phase 7: at least two delivered order records per customer_unique_id.
WITH delivered_customer_orders AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS delivered_customers,
       COUNT(CASE WHEN delivered_orders >= 2 THEN 1 END) AS customers_with_2plus_delivered_orders,
       ROUND(100.0 * COUNT(CASE WHEN delivered_orders >= 2 THEN 1 END)
             / NULLIF(COUNT(*), 0), 2) AS second_purchase_rate_pct
FROM delivered_customer_orders;

-- ============================================================================
-- SECTION K-L: HORIZON COMPARISON AND MATURE COHORTS
-- ============================================================================
-- Questions 8-10: Month 1/2/3 retention. A horizon is reportable only when
-- that complete calendar month ended by the beginning of the dataset's final
-- delivered purchase month. Mature means three complete post-cohort months
-- were available: cohort_month + 4 months <= dataset_end_month (month starts).
-- Missing activity for a fully observed horizon is zero; an immature horizon is NULL.
WITH delivered_orders AS (
    SELECT o.order_id, c.customer_unique_id,
           DATE_SUB(DATE(o.order_purchase_timestamp),
               INTERVAL DAYOFMONTH(o.order_purchase_timestamp) - 1 DAY) AS purchase_month
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM delivered_orders GROUP BY customer_unique_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts GROUP BY cohort_month
),
customer_month_activity AS (
    SELECT DISTINCT d.customer_unique_id, cc.cohort_month, d.purchase_month,
           TIMESTAMPDIFF(MONTH, cc.cohort_month, d.purchase_month) AS month_number
    FROM delivered_orders AS d
    JOIN customer_cohorts AS cc ON cc.customer_unique_id = d.customer_unique_id
),
active_counts AS (
    SELECT cohort_month, month_number, COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM customer_month_activity GROUP BY cohort_month, month_number
),
dataset_end AS (
    SELECT MAX(purchase_month) AS dataset_end_month FROM delivered_orders
),
month_offsets AS (
    SELECT 1 AS month_number UNION ALL SELECT 2 UNION ALL SELECT 3
),
cohort_horizons AS (
    SELECT cs.cohort_month, cs.cohort_size, mo.month_number, de.dataset_end_month,
           COALESCE(ac.active_customers, 0) AS active_customers
    FROM cohort_sizes AS cs CROSS JOIN month_offsets AS mo CROSS JOIN dataset_end AS de
    LEFT JOIN active_counts AS ac
      ON ac.cohort_month = cs.cohort_month AND ac.month_number = mo.month_number
)
SELECT cohort_month, cohort_size,
       MAX(CASE WHEN month_number = 1 AND DATE_ADD(cohort_month, INTERVAL 2 MONTH) <= dataset_end_month
                THEN ROUND(100.0 * active_customers / NULLIF(cohort_size, 0), 2) END) AS month_1_retention_pct,
       MAX(CASE WHEN month_number = 2 AND DATE_ADD(cohort_month, INTERVAL 3 MONTH) <= dataset_end_month
                THEN ROUND(100.0 * active_customers / NULLIF(cohort_size, 0), 2) END) AS month_2_retention_pct,
       MAX(CASE WHEN month_number = 3 AND DATE_ADD(cohort_month, INTERVAL 4 MONTH) <= dataset_end_month
                THEN ROUND(100.0 * active_customers / NULLIF(cohort_size, 0), 2) END) AS month_3_retention_pct
FROM cohort_horizons
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;

-- Mature-cohort comparison only: all cohorts listed have 3 full calendar
-- months after cohort month observable before the dataset-end month began.
WITH delivered_orders AS (
    SELECT o.order_id, c.customer_unique_id,
           DATE_SUB(DATE(o.order_purchase_timestamp),
               INTERVAL DAYOFMONTH(o.order_purchase_timestamp) - 1 DAY) AS purchase_month
    FROM orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM delivered_orders GROUP BY customer_unique_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts GROUP BY cohort_month
),
customer_month_activity AS (
    SELECT DISTINCT d.customer_unique_id, cc.cohort_month, d.purchase_month,
           TIMESTAMPDIFF(MONTH, cc.cohort_month, d.purchase_month) AS month_number
    FROM delivered_orders AS d
    JOIN customer_cohorts AS cc ON cc.customer_unique_id = d.customer_unique_id
),
active_counts AS (
    SELECT cohort_month, month_number, COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM customer_month_activity GROUP BY cohort_month, month_number
),
dataset_end AS (
    SELECT MAX(purchase_month) AS dataset_end_month FROM delivered_orders
),
month_offsets AS (
    SELECT 1 AS month_number UNION ALL SELECT 2 UNION ALL SELECT 3
),
cohort_horizons AS (
    SELECT cs.cohort_month, cs.cohort_size, mo.month_number, de.dataset_end_month,
           COALESCE(ac.active_customers, 0) AS active_customers
    FROM cohort_sizes AS cs CROSS JOIN month_offsets AS mo CROSS JOIN dataset_end AS de
    LEFT JOIN active_counts AS ac
      ON ac.cohort_month = cs.cohort_month AND ac.month_number = mo.month_number
    WHERE DATE_ADD(cs.cohort_month, INTERVAL 4 MONTH) <= de.dataset_end_month
)
SELECT cohort_month, cohort_size,
       MAX(CASE WHEN month_number = 1 THEN ROUND(100.0 * active_customers / NULLIF(cohort_size, 0), 2) END)
           AS month_1_retention_pct,
       MAX(CASE WHEN month_number = 2 THEN ROUND(100.0 * active_customers / NULLIF(cohort_size, 0), 2) END)
           AS month_2_retention_pct,
       MAX(CASE WHEN month_number = 3 THEN ROUND(100.0 * active_customers / NULLIF(cohort_size, 0), 2) END)
           AS month_3_retention_pct
FROM cohort_horizons
GROUP BY cohort_month, cohort_size ORDER BY cohort_month;

-- ============================================================================
-- SECTION M: LIMITATIONS AND INTERVIEW CONCEPTS
-- ============================================================================
-- Retention is observed only within this dataset window; customers may purchase
-- outside it. No purchase in an observed month does not prove churn. Later
-- cohorts have shorter observation periods. Repeat purchasing is relatively
-- uncommon in the Olist data context; verify Phase 7 outputs before quoting a
-- numeric rate. Interpret cohort retention cautiously and descriptively.
-- Revenue per original cohort customer is historical observed revenue, not LTV.
--
-- INTERVIEW CONCEPTS DEMONSTRATED
-- Cohort definition; customer-level grain; first-purchase logic; month indexing;
-- retention calculation; COUNT DISTINCT; conditional aggregation; observation-
-- window bias; mature-cohort filtering; and revenue by cohort.