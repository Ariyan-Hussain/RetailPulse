# RetailPulse Retention KPI Definitions

These definitions apply to `sql/07_cohort_retention_analysis.sql`. The purchase population is orders with `order_status = 'delivered'`; cross-order identity is `customers.customer_unique_id`, joined from each order through its order-specific `customer_id`. Revenue is the sum of delivered `order_items.price` only. Freight, payment values, and profit are excluded. None of these measures is a churn prediction.

## Cohort Month
- **Definition:** Calendar month containing a customer's first delivered purchase.
- **Grain:** One row per `customer_unique_id`.
- **Filter:** Delivered orders only.
- **Formula:** Minimum delivered purchase date; normalize it to the first day of that month.
- **Caveats:** `customer_unique_id` is the source's anonymized identity. `customer_id` is not used as cross-order identity.

## Cohort Size
- **Definition:** Number of distinct delivered customers first purchasing in a cohort month.
- **Grain:** Cohort month.
- **Filter:** Customers with at least one delivered order.
- **Formula:** `COUNT(DISTINCT customer_unique_id)` grouped by `cohort_month`.
- **Caveats:** It is a starting population count, not a forecast.

## Activity Month
- **Definition:** Calendar month in which a customer placed a delivered order.
- **Grain:** Customer and purchase month.
- **Filter:** Delivered orders only.
- **Formula:** First day of the month of `order_purchase_timestamp`.
- **Caveats:** A customer with multiple delivered orders in one month is one active customer for that month.

## Months Since First Purchase
- **Definition:** Number of calendar-month boundaries from cohort month to activity month.
- **Grain:** Customer-month activity record, summarized by cohort and month offset.
- **Filter:** Delivered activity on or after first delivered purchase.
- **Formula:** `TIMESTAMPDIFF(MONTH, cohort_month, purchase_month)` using first-of-month dates.
- **Caveats:** Cohort month is 0; the next calendar month is 1. Negative values indicate a logic/data issue.

## Active Cohort Customer
- **Definition:** Distinct cohort member with at least one delivered order in an activity month.
- **Grain:** One customer per cohort month and activity month.
- **Filter:** Delivered orders.
- **Formula:** Count distinct `customer_unique_id` within the cohort and month offset.
- **Caveats:** Multiple monthly orders do not increase the count.

## Cohort Retention Rate
- **Definition:** Share of the original cohort active in a given month offset.
- **Grain:** Cohort month and month offset.
- **Filter:** Delivered orders.
- **Formula:** `active_customers / cohort_size * 100`, with defensive `NULLIF` division.
- **Caveats:** Month 0 should be 100%. A zero-activity mature month is zero; an unobserved/immature horizon is NULL in the horizon-comparison query. Retention is observed behavior, not proof of continued or ended customer relationship.

## Second Purchase Rate
- **Definition:** Percentage of delivered customers with at least two delivered orders.
- **Grain:** Customer.
- **Filter:** Delivered orders only.
- **Formula:** Customers with 2+ distinct delivered orders divided by all delivered customers, times 100.
- **Caveats:** This should align with Phase 7's repeat-customer rate when the same population and customer identity are used. It is not churn or a prediction.

## Days to Second Purchase
- **Definition:** Calendar days from the first delivered purchase date to the second delivered purchase date.
- **Grain:** One second-purchase interval per customer who has a second delivered order.
- **Filter:** Delivered orders ordered by timestamp, with `order_id` as a deterministic tie-break.
- **Formula:** `DATEDIFF(second_purchase_date, first_purchase_date)`.
- **Caveats:** Same-day purchases can yield zero. Suggested ranges describe observed timing only and are not churn thresholds.

## Cohort Revenue
- **Definition:** Delivered item-price revenue produced in each cohort activity month.
- **Grain:** Cohort month and months since first purchase.
- **Filter:** Delivered orders and their item lines.
- **Formula:** Aggregate `SUM(order_items.price)` to order first, then sum order revenue by cohort and month offset.
- **Caveats:** Freight, payments, non-delivered orders, and profit/cost are excluded. Orders without item rows contribute zero in the query's order set.

## Revenue per Original Cohort Customer
- **Definition:** Observed cohort-month revenue divided by the original number of customers in that cohort.
- **Grain:** Cohort month and month offset.
- **Filter:** Same as cohort revenue.
- **Formula:** `cohort_revenue / cohort_size`.
- **Caveats:** This is historical revenue per original cohort member, not lifetime value (LTV), because the observation window is limited.

## Mature Cohort
- **Definition:** Cohort with three complete post-cohort calendar months observable before the dataset-end month begins.
- **Grain:** Cohort month.
- **Filter:** Delivered orders define the dataset end month.
- **Formula:** `DATE_ADD(cohort_month, INTERVAL 4 MONTH) <= dataset_end_month`, where both are first-of-month dates. This leaves month offsets 1, 2, and 3 as complete calendar months before the final dataset month.
- **Caveats:** Newer cohorts are excluded from the mature-only comparison. Maturity is about available observation time, not customer status.

## General interpretation limits

The data only records activity within its historical observation window. Customers may purchase outside it; missing activity within the dataset does not prove churn. Newer cohorts have less possible follow-up. Compare only horizons available to each cohort, and present findings descriptively without causal claims or recommendations.