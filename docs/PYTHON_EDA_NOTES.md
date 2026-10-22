# RetailPulse Python EDA Notes

## Method

From the project root: create an environment with py -m venv .venv; install dependencies with .venv\Scripts\python.exe -m pip install -r python\requirements-eda.txt; run with .venv\Scripts\python.exe python\retailpulse_eda.py. Dependencies are pandas, numpy, and matplotlib. No Jupyter runtime was available, so this standalone script runs the analysis and saves its charts and notes. It reads original CSVs in data/raw and independently reproduces SQL definitions; it does not connect to MySQL or modify CSVs. Delivered orders define completed purchases; customer identity is customer_unique_id joined through customer_id. Revenue is SUM(order_items.price); freight and payments are excluded. Item lines are aggregated to order grain before customer/order metrics. SQL result files were unavailable, so no numerical SQL equality is claimed.

## FACT — outputs from this run

- Source rows: customers 99,441; orders 99,441; items 112,650; products 32,951; translations 71.
- Delivered orders 96,478; unique delivered customers 93,358; delivered item-price revenue 13,221,498.11; average order value 137.04.
- Timestamp range 2016-09-15 12:16:38 through 2018-08-29 15:00:37; monthly periods 24; missing internal months 1; first/last months partial True/True.
- Repeat customers 2,801 of 93,358; repeat rate 3.0003%. Frequency buckets: {'1 order': 90557, '2 orders': 2573, '3 orders': 181, '4 orders': 28, '5+ orders': 19}.
- Consecutive purchase interval count 3,120; average 79.15 days; median 29.00 days.
- Customer revenue mean/median/std/min/Q1/Q3/max: 141.62/89.73/215.69/0.85/47.65/154.74/13440.00.
- Highest-revenue full observed month (excluding partial endpoints): 2017-11, 987,765.37.
- Largest adjacent full-month revenue increase: 2017-11, +339,517.72; largest decrease: 2017-12, -261,732.18.
- Highest-revenue category: health_beauty, 1,233,131.72 revenue, 8,647 orders, 9,465 item lines.
- Highest-revenue customer state: SP, 5,067,633.16 revenue across 40,501 orders and 39,156 delivered customers.
- Item lines without English category translation (source fallback used): 1,559.
- Order revenue count/mean/median/std/min/Q1/Q3/max: 96478/137.04/86.57/209.05/0.85/45.90/149.90/13440.00.
- Customer revenue skewness 9.7469; top 10% of customers by count contribute 41.0999% of delivered customer revenue.
- Cohort validation checks: {"month_0_100_percent": true, "no_negative_months": true, "positive_cohort_sizes": true, "retention_at_most_100_percent": true}; month-zero cohort rows checked 23.
- IQR fences -110.10 and 305.90; flagged orders 7,659; top flagged examples (all need manual review): 03caa2c082116e1d31e67e9ae3700499: 13440.00 revenue / 8 item lines; 736e1922ae60d0d6a89247b851902527: 7160.00 revenue / 4 item lines; 0812eb902a67711a1cb742b3cdaa65ae: 6735.00 revenue / 1 item lines; fefacc66af859508bf1a7934eab1e97f: 6729.00 revenue / 1 item lines; f5136e38d1a14a4dbd87dff67da82701: 6499.00 revenue / 1 item lines.
- Lowest-revenue category: security_and_services, 283.29 over 2 orders and 2 item lines; low volume is context, not a failure label.
- Correlations: item price/freight 0.4127; order revenue/item count 0.1535.
- SQL/Python numerical cross-check: unavailable because SQL result outputs were not provided.

## INTERPRETATION — descriptive only

Mean order revenue is above the median; this describes the observed distribution, not its cause. Skewness and top-decile contribution summarize concentration but do not imply that high-revenue customers are inherently better. No causal conclusion or recommendation is made.

Any correlations are descriptive. Association does not establish causality. No hypothesis tests, churn labels, profit calculations, predictive models, or recommendations are included.

## Outlier approach

Order revenue is flagged using Tukey fences: below Q1 - 1.5 x IQR (-110.10) or above Q3 + 1.5 x IQR (305.90). All current IQR flags are classified as needing manual review until source rows and business context are checked. After review, a structurally sound plausible value may be classified as a valid extreme observation; invalid numbers or broken keys may be classified as possible data-quality issues. No observations are removed or winsorized; charts include all orders.

## Checks and caveats

Orders unmatched to customers: 0. Item rows with missing parent orders/products were checked and none were found. Key uniqueness checks passed for customer_id, order_id, (order_id, order_item_id), product_id, and translation category. Negative item prices: 0; zero prices: 0.
Monthly gaps are filled with zero for charting. The first and last observed calendar months can be partial. Category label fallback matches SQL: English translation, source category, then Unknown. State AOV is the mean of one revenue total per delivered order.
Cohort month is first delivered purchase month; activity is distinct customer-month; month indexing uses calendar-month arithmetic. Checks cover month 0 at 100%, no retention above 100%, nonnegative indexes, and positive cohort sizes.
This Python run uses raw CSVs, not imported MySQL tables. The approved definitions were followed, but numeric equality with SQL outputs was not established. Olist is historical and incomplete beyond its observation window; absence of purchase is not churn. Freight is not seller cost and the data has no profit field.

## Charts

Generated charts are in images/python: monthly revenue, monthly delivered order count, order revenue histogram and box plot, customer revenue, top categories, customer-state revenue, purchase frequency, and days between purchases.
