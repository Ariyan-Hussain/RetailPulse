# RetailPulse Power BI DAX Measure Plan

These measures preserve the approved definitions: delivered orders for completed-purchase KPIs and `order_items.price` only for revenue. Names follow `POWER_BI_MODEL.md`. Use measures for aggregations; imported keys/attributes remain columns.

## Core measures

```DAX
Delivered Revenue =
CALCULATE(
    SUM(FactOrderItems[price]),
    FactOrderItems[order_status] = "delivered"
)

Delivered Orders =
CALCULATE(
    DISTINCTCOUNT(FactOrders[order_id]),
    FactOrders[order_status] = "delivered"
)

Delivered Customers =
CALCULATE(
    DISTINCTCOUNT(FactOrders[customer_unique_id]),
    FactOrders[order_status] = "delivered"
)

Average Order Value =
CALCULATE(
    AVERAGE(FactOrders[order_item_revenue]),
    FactOrders[order_status] = "delivered"
)

Item Lines Sold =
CALCULATE(
    COUNTROWS(FactOrderItems),
    FactOrderItems[order_status] = "delivered"
)
```

`FactOrders[order_item_revenue]` must be pre-aggregated to one value/order by summing item price first, left-joining to orders, and setting missing item totals to zero. This reproduces order-grain AOV; averaging item rows would be wrong.

## Customer measures

`CustomerMetrics` has one row per delivered `customer_unique_id` for the full observation window. These repeat measures are full-window measures, not dynamic state/date/product results.

```DAX
Repeat Customers =
CALCULATE(
    DISTINCTCOUNT(CustomerMetrics[customer_unique_id]),
    CustomerMetrics[delivered_orders] >= 2
)

Repeat Customer Rate =
DIVIDE(
    [Repeat Customers],
    DISTINCTCOUNT(CustomerMetrics[customer_unique_id])
)

Second Purchase Rate =
[Repeat Customer Rate]

Revenue per Customer =
DIVIDE(
    [Delivered Revenue],
    [Delivered Customers]
)
```

Format repeat and second-purchase rates as percentages. These names refer to the same delivered-customer definition (two or more delivered orders), not separate metrics. Revenue per customer uses delivered item-price revenue divided by unique delivered customers under shared date/customer filters. A product filter affects the item-fact numerator but not the separate order-fact denominator. If showing this under product selection, create a clearly labelled item-context version whose denominator is distinct `FactOrderItems[customer_unique_id]` in that same product context.

Use the existing Phase 7 monthly SQL result (`MonthlyCustomerActivity`) for new/repeat trends:

```DAX
New Customers =
SUM(MonthlyCustomerActivity[new_customers])

Repeat Purchasing Customers (Month) =
IF(
    HASONEVALUE(DimDate[Year-Month]),
    SUM(MonthlyCustomerActivity[repeat_customers]),
    BLANK()
)

New Customer Revenue =
SUM(MonthlyCustomerActivity[new_customer_revenue])

Repeat Customer Revenue =
SUM(MonthlyCustomerActivity[repeat_customer_revenue])
```

Plot monthly counts by month. The repeat-customer count is distinct within each month. Summing multiple months counts customer-month activity rather than unique people, so the repeat measure returns blank unless exactly one month is in context. Monthly SQL values do not break down by product or state.

## Trend measures

```DAX
Monthly Revenue =
[Delivered Revenue]

Previous Month Revenue =
CALCULATE(
    [Delivered Revenue],
    DATEADD(DimDate[Date], -1, MONTH)
)

MoM Revenue Growth % =
DIVIDE(
    [Delivered Revenue] - [Previous Month Revenue],
    [Previous Month Revenue]
)
```

Use the continuous, marked `DimDate` and sort Year-Month chronologically. `DIVIDE` returns blank when there is no prior month or prior-month revenue is zero, matching SQL `NULL` behavior. Format as percentage; do not replace undefined comparisons with zero.

## Product measures

```DAX
Category Revenue =
[Delivered Revenue]

Product Revenue =
[Delivered Revenue]

Category Revenue Share % =
DIVIDE(
    [Category Revenue],
    CALCULATE(
        [Delivered Revenue],
        REMOVEFILTERS(DimProducts)
    )
)

Average Item Price =
DIVIDE(
    [Delivered Revenue],
    [Item Lines Sold]
)
```

Use translated category or `product_id` on axes. Product names are absent from the source; do not invent them. Category share removes product filters from its denominator but keeps date/customer/seller filters.

## Regional measure

```DAX
State Revenue =
[Delivered Revenue]
```

Use `DimCustomers[customer_state]`, sourced from the order-linked customer record; it is not a geolocation-derived delivery state.

## Cohort and second-purchase outputs

Do not recreate cohort calculations in DAX. Import `CohortRetention` from Phase 8 SQL at `(cohort_month, month_number)` grain. Display its `retention_rate_pct` in a matrix at one cohort/offset cell; disable totals that would add percentages. Preserve blank immature horizons. Retention is observed within the dataset, not churn.

For a second-purchase headline, import the one-row aggregate from the Phase 8 SQL and display its `average_days_to_second_purchase` value. A `MAX` over that one-row result only displays the precomputed metric; it does not recalculate it. Use the SQL distribution output for a distribution chart.

## Formatting and guardrails

- Revenue, AOV, item price: consistent currency format.
- Counts: whole numbers. Rates: percentage format.
- Imported SQL percentages may be 0-100; DAX ratios above are fractions. Convert only once and label units.
- Preserve blank for undefined ratios/prior periods; do not coalesce them to invented zeroes.
- No profit, margin, churn, or causal measures.
