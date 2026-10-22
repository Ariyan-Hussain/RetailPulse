# RetailPulse Power BI Manual Build Guide

This guide plans a manual Desktop build. No PBIX or screenshots were created in Phase 10 design preparation.

## Before you begin

- MySQL 8 is running and the `retailpulse` database has passed Phase 5 validation.
- Install Power BI Desktop and Oracle MySQL Connector/NET. See Microsoft's [MySQL connector requirements](https://learn.microsoft.com/en-us/power-query/connectors/mysql-database).
- Use a read-only database account. Enter its credentials only into Power BI's local credential prompt; do not put passwords in M queries, Git, screenshots, or documentation.
- Use Import mode first. Refresh in Desktop requires the local MySQL server to be running. Refresh from Power BI service for a local server requires a standard on-premises data gateway. See Microsoft's [Import and DirectQuery overview](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-use-directquery).

## 1. Open Power BI Desktop

Create a blank report. After the first successful connection, save the actual report locally as `powerbi/RetailPulse.pbix`. Do not commit credentials or fabricate a PBIX artifact.

## 2-3. Connect to the recommended source

1. Choose **Get data > MySQL database**.
2. Enter the local MySQL server (often `127.0.0.1:3306`) and database `retailpulse`.
3. Select **Import**.
4. At the credential prompt, use your local read-only MySQL login. Never paste the password into chat or a source file.
5. In Navigator select required tables and choose **Transform Data**.

MySQL is preferred because it is the validated source of truth and is reproducible. CSV extracts are a fallback if Connector/NET cannot be installed; export them from validated SQL, record the export date, and expect manual refresh.

## 4-5. Import and shape tables

Import `orders`, `order_items`, `customers`, `products`, `sellers`, and `product_category_translations`. Omit payments and reviews on the first pass.

In Power Query:

1. Set IDs (`order_id`, `customer_id`, `customer_unique_id`, `product_id`, `seller_id`) to Text.
2. Set purchase timestamps to Date/Time and create a Date-only `purchase_date` for relationships.
3. Keep `price` and `freight_value` numeric. Keep freight separate from revenue.
4. Build `FactOrderItems` at original item-line grain by joining each item to one order and its order-linked customer record. Check the `(order_id, order_item_id)` key and row count before/after merges; each should remain unchanged.
5. Build `FactOrders` at one row/order. Group item `price` by `order_id` before merging into orders. Use a left merge and replace missing item totals with zero. Do not join payments to item lines.
6. Build `DimCustomers` at one row/customer_id, with `customer_unique_id`, city, and state.
7. Build `DimProducts` at one row/product_id. Left-merge translations and apply the existing display fallback: translated category, original source category, then `Unknown`. Keep products with no category.
8. Build `DimSellers` at one row/seller_id.
9. Export a one-row-per-customer result as `CustomerMetrics` using the existing Phase 7 customer-summary CTE logic; the SQL script does not create a permanent summary table. Import the Phase 7 monthly output as `MonthlyCustomerActivity` and convert its `YYYY-MM` text field to the first date of that month. Import Phase 8 long-form retention and cohort revenue outputs as `CohortRetention`; rename the revenue query's `months_since_first_purchase` to `month_number` before merging. These may be saved SQL query results. Preserve their source and grain; do not invent values or redefine KPIs in Power Query.
10. Rename queries using the model names, then select **Close & Apply**.

## 6. Create relationships

In Model view, create one-to-many, single-direction relationships as specified in `POWER_BI_MODEL.md`:

- `DimDate[Date]` to purchase date in both facts; also to summary month/cohort keys where intended.
- `DimCustomers[customer_id]` to both facts.
- `DimProducts[product_id]` and `DimSellers[seller_id]` to `FactOrderItems` only.

Check that each dimension key is unique. Do not create a fact-to-fact relationship, many-to-many relationship on repeated `customer_unique_id`, or bidirectional relationship to force interactions. Product/seller filters do not filter `FactOrders` or full-window customer summaries automatically.

## 7. Create the date table

Create a continuous `DimDate` from the minimum through maximum observed `FactOrders[purchase_date]` (all order statuses). Add Date, Year, Quarter, Month Number, Month Name, Year-Month, and Year-Month Sort (`Year * 100 + Month Number`). Sort Year-Month by Year-Month Sort and mark `DimDate[Date]` as the date column. Add a Monday-start week number only if you build a weekly view. Monthly SQL extracts store the first day of each month; use full-month Year-Month selections for monthly summaries. Arbitrary mid-month date filters can exclude a month-summary row.

## 8. Create measures

Add the DAX from `POWER_BI_DAX_MEASURES.md`. Format counts as whole numbers, rates as percentages, and item-price revenue consistently as currency. Confirm AOV averages order-level item revenue, not item rows. Do not add profit, margin, or churn measures.

## 9-10. Build four pages

### Page 1 - Executive Overview

- Cards: Delivered Revenue, Delivered Orders, Delivered Customers, Average Order Value, Repeat Customer Rate.
- Line chart: Monthly Revenue by Year-Month.
- Column/line chart: Monthly Delivered Orders.
- Bar charts: Revenue by translated category and customer state.
- Slicers: date, customer state, product category.
- Label Repeat Customer Rate as full-window. Configure interactions so product filters do not appear to change order-grain cards that are based on `FactOrders`.

### Page 2 - Product Performance

- Top 10 categories and top 10 products by delivered revenue.
- Category revenue share, item lines, and average item price.
- Detail table: `product_id`, category, revenue, distinct orders containing the product, item-line count, average item price.
- The source contains no product name; identify products by `product_id`.

### Page 3 - Customer Analytics

- Delivered customers, full-window repeat customers, repeat rate, and revenue per customer.
- One-time/repeat frequency distribution and customer-revenue distribution using `customer_unique_id`.
- Top customers by delivered item-price revenue.
- New versus repeat customers and revenue by month from `MonthlyCustomerActivity`.
- Explain that a customer can appear as new and repeat in the same month. Monthly pre-aggregates do not break down by product or state.

### Page 4 - Retention & Cohort

- Second-purchase rate and average days to second purchase from Phase 8 SQL.
- Matrix: cohort month on rows, month number on columns, precomputed retention percentage as values.
- Month 1/2/3 retention by cohort, with immature horizons blank.
- Days-to-second-purchase distribution from the existing SQL distribution result.
- Cohort revenue by cohort and elapsed month.
- Include: ?Retention is observed within the available dataset window. No observed purchase does not prove churn. Later cohorts have shorter follow-up.?

## 11. Slicers and interaction checks

Add date, state, category, and product slicers only where the relationships support the intended behavior. Test each slicer separately. Item-fact measures respond to product/category; `FactOrders` and full-window `CustomerMetrics` do not automatically respond to product selections. Keep interactions disabled for incompatible visuals or use a separately labelled item-context measure. Do not make a full-window repeat metric look date-sensitive when it is not.

## 12. Visual design rules

- Cards for headline KPIs, lines for trends, bars for rankings, and a matrix/heatmap for cohorts.
- Avoid 3D charts and excessive pie/donut charts.
- Use consistent currency, percent, and date formats, descriptive titles, readable axes, and intentional whitespace.
- Avoid misleading truncated axes; use a restrained consistent palette.
- Mark partial first/last months; do not compare them as complete months without a note.

## 13. Validate

Follow `POWER_BI_VALIDATION.md`. Compare the same filters and grains to matching SQL output. Phase 9 Python is a definition-level checkpoint, not proof of SQL equality. Record actual values only after running the comparison.

## 14-15. Save and capture real screenshots

Save the real report as `powerbi/RetailPulse.pbix`. After each page is built and validated, save genuine screenshots under `images/powerbi/`:

- `executive_dashboard.png`
- `product_dashboard.png`
- `customer_dashboard.png`
- `retention_dashboard.png`

Do not create placeholders. Review images for credentials, personal information, or private connection details before sharing. Do not publish the report until data-sharing settings have been reviewed.

## Troubleshooting

- **MySQL source missing:** install Oracle MySQL Connector/NET and restart Power BI Desktop.
- **Connection refused:** check the MySQL service and local host/port.
- **Access denied:** check local read-only user grants; never share the password in chat.
- **Totals inflated after merges:** verify fact grain and unique dimension keys; do not join payments to items.
- **Months sorted alphabetically:** sort Year-Month by Year-Month Sort.
- **SQL/Python totals differ:** compare delivered filter, item-price revenue, customer identity, purchase-date basis, category fallback, and aggregation grain before changing a measure.
