# RetailPulse — E-Commerce Revenue, Customer Behaviour & Retention Analytics

RetailPulse is an end-to-end data analytics project built to analyze e-commerce revenue, customer behaviour, product performance, geographic performance, repeat purchases, and customer retention.

The project uses **MySQL, Python, and Power BI** to transform raw transactional data into validated business insights and interactive dashboards.

---

## Project Objective

The goal of RetailPulse is to simulate a real-world Data Analyst workflow:

**Raw Data → Data Validation → SQL Analysis → Python EDA → KPI Validation → Power BI Dashboard → Business Insights**

The project focuses on answering practical business questions such as:

- How much revenue is generated from completed orders?
- How many customers make repeat purchases?
- Which product categories generate the most revenue?
- Which customer states contribute the most revenue?
- How does revenue change over time?
- What percentage of customers return for another purchase?
- How do customer cohorts behave after their first purchase?

---

## Dataset

This project uses the **Brazilian E-Commerce Public Dataset by Olist**.

The dataset contains multiple relational tables covering:

- Customers
- Orders
- Order items
- Products
- Sellers
- Payments
- Reviews
- Product category translations
- Geographic information

The raw dataset contains approximately **100,000 orders** across the 2016–2018 period.

> Raw dataset files are intentionally excluded from the repository.

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| MySQL 8.0 | Data storage, joins, KPI calculations, customer analysis, cohort analysis |
| SQL | Data validation, business analysis, CTEs, window functions, aggregation |
| Python | Exploratory data analysis and independent KPI validation |
| Pandas | Data cleaning and analysis |
| NumPy | Supporting numerical analysis |
| Matplotlib | Data visualizations |
| Power BI | Data modelling, DAX measures, interactive dashboards |
| Git & GitHub | Version control and project documentation |

---

## Data Model

The Power BI model uses separate fact and dimension tables to avoid duplicated calculations.

### Fact Tables

- `FactOrders`
- `FactOrderItems`

### Dimension Tables

- `DimCustomers`
- `DimProducts`
- `DimSellers`
- `DimDate`

### Core Relationships

```text
DimCustomers
      |
      | 1:*
      v
FactOrders
      |
      | 1:*
      v
FactOrderItems
     /       \
    /         \
DimProducts   DimSellers

DimDate
   |
   | 1:*
   v
FactOrders
```

Cross-filter direction is kept **Single** for the main relationships.

---

## Business Rules

To maintain consistent KPI definitions:

- Core revenue analysis uses **delivered orders only**.
- Revenue is calculated using `order_items.price`.
- Freight is analyzed separately and is not treated as seller cost.
- `customer_unique_id` is used to identify customers across multiple orders.
- `customer_id` is retained as the order-linked customer key.
- Payments are not directly joined to order items at item level to avoid fanout duplication.
- Missing future purchases are not automatically interpreted as churn.
- Retention results are limited to the observable historical period.

---

## Key KPI Definitions

### Delivered Orders

Number of unique delivered orders.

```DAX
Delivered Orders =
CALCULATE(
    DISTINCTCOUNT(FactOrders[order_id]),
    FactOrders[order_status] = "delivered"
)
```

### Delivered Customers

Number of unique customers with at least one delivered order.

```DAX
Delivered Customers =
COUNTROWS(
    FILTER(
        VALUES(DimCustomers[customer_unique_id]),
        CALCULATE(
            DISTINCTCOUNT(FactOrders[order_id]),
            FactOrders[order_status] = "delivered"
        ) > 0
    )
)
```

### Revenue

Revenue from delivered order items.

```DAX
Revenue =
CALCULATE(
    SUM(FactOrderItems[price]),
    FactOrders[order_status] = "delivered"
)
```

### Average Order Value

```DAX
AOV =
DIVIDE(
    [Revenue],
    [Delivered Orders],
    0
)
```

### Repeat Customers

Customers with at least two delivered orders.

```DAX
Repeat Customers =
COUNTROWS(
    FILTER(
        VALUES(DimCustomers[customer_unique_id]),
        CALCULATE(
            DISTINCTCOUNT(FactOrders[order_id]),
            FactOrders[order_status] = "delivered"
        ) >= 2
    )
)
```

### Repeat Customer Rate

```DAX
Repeat Customer Rate =
DIVIDE(
    [Repeat Customers],
    [Delivered Customers],
    0
)
```

---

## Validated KPI Results

The major KPIs were independently validated across SQL, Python, and Power BI.

| KPI | Result |
|---|---:|
| Delivered Orders | 96,478 |
| Delivered Customers | 93,358 |
| Delivered Revenue | 13,221,498.11 |
| Average Order Value | ~137.04 |
| Repeat Customer Rate | ~3.0003% |

These checkpoints were used to verify that the data model and DAX measures were producing consistent results.

---

## SQL Analysis

The SQL layer contains progressively more advanced analysis.

### Core Analysis

`sql/05_analysis_foundation.sql`

Includes:

- Order overview
- Customer overview
- Revenue analysis
- Average order value
- Monthly revenue trends
- Monthly customer trends
- Month-over-month growth
- Product category performance
- Product performance
- State-level analysis

### Customer Analysis

`sql/06_customer_analysis.sql`

Includes:

- Purchase frequency
- One-time vs repeat customers
- Repeat customer rate
- Top customers by revenue
- New vs repeat customers
- Revenue from new vs repeat customers
- Days between purchases
- Customer state analysis
- Category breadth
- Revenue concentration
- Customer recency bands

### Cohort & Retention Analysis

`sql/07_cohort_retention_analysis.sql`

Includes:

- First-purchase cohort assignment
- Months since first purchase
- Cohort size
- Active customers
- Retention rate
- Cohort retention matrix
- Cohort revenue
- Revenue per original cohort customer
- Days to second purchase
- Second purchase rate
- M1 / M2 / M3 retention comparison
- Mature cohort filtering

---

## Python EDA

Python was used to independently validate SQL results and investigate distributions and trends.

Main script:

```text
python/retailpulse_eda.py
```

Key outputs include:

- Monthly revenue trend
- Monthly order trend
- Order revenue distribution
- Customer revenue distribution
- Top categories
- State revenue
- Purchase frequency
- Purchase interval analysis

Generated visualizations are stored in:

```text
images/python/
```

The Python validation confirmed the same major KPI checkpoints used in SQL and Power BI.

---

## Power BI Dashboard

The Power BI report contains four pages.

### 1. Executive Overview

Focuses on high-level business performance:

- Delivered Orders
- Delivered Customers
- Revenue
- Average Order Value
- Repeat Customer Rate
- Monthly Revenue Trend
- Monthly Delivered Orders Trend

### 2. Product Performance

Focuses on product and regional performance:

- Top 10 Categories by Revenue
- Top Products by Revenue
- Revenue by Customer State

### 3. Customer Analytics

Focuses on customer behaviour:

- Delivered Customers
- Repeat Customers
- Repeat Customer Rate
- Customers by State

### 4. Retention & Cohort

Summarizes repeat-purchase and retention analysis.

The detailed cohort calculations were performed and validated in SQL and Python.

---

## Dashboard Screenshots

### Executive Overview

![Executive Overview](images/powerbi/01_executive_overview.png)

### Product Performance

![Product Performance](images/powerbi/02_product_performance.png)

### Customer Analytics

![Customer Analytics](images/powerbi/03_customer_analytics.png)

### Retention & Cohort

![Retention and Cohort](images/powerbi/04_retention_cohort.png)

---

## Project Structure

```text
RetailPulse/
│
├── data/
│   ├── raw/
│   └── cleaned/
│
├── docs/
│   ├── PROJECT_SCOPE.md
│   ├── DATASET_REQUIREMENTS.md
│   ├── DATA_DICTIONARY.md
│   ├── DATA_MODEL_NOTES.md
│   ├── DATA_QUALITY_AUDIT.md
│   ├── DATA_CLEANING_STRATEGY.md
│   ├── MYSQL_SCHEMA_DESIGN.md
│   ├── IMPORT_VALIDATION.md
│   ├── KPI_DEFINITIONS.md
│   ├── CUSTOMER_KPI_DEFINITIONS.md
│   ├── RETENTION_KPI_DEFINITIONS.md
│   ├── POWER_BI_MODEL.md
│   ├── POWER_BI_DAX_MEASURES.md
│   ├── POWER_BI_VALIDATION.md
│   ├── POWER_BI_BUILD_GUIDE.md
│   └── PYTHON_EDA_NOTES.md
│
├── sql/
│   ├── 00_reset_database.sql
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_load_data.sql
│   ├── 04_validation_checks.sql
│   ├── 05_analysis_foundation.sql
│   ├── 06_customer_analysis.sql
│   └── 07_cohort_retention_analysis.sql
│
├── python/
│   ├── retailpulse_eda.py
│   ├── diagnose_import.py
│   ├── requirements-eda.txt
│   └── eda_kpi_validation.csv
│
├── powerbi/
│   └── RetailPulse.pbix
│
├── images/
│   ├── python/
│   └── powerbi/
│
├── .gitignore
└── README.md
```

---

## Data Quality & Validation

Several validation checks were performed before analysis.

Confirmed results include:

- No major orphan relationship issues
- No negative item prices
- No negative freight values
- Order and customer keys validated
- MySQL row counts matched the original CSV source files after import correction
- Delivered order population confirmed at **96,478**
- Customer identity validated using `customer_unique_id`
- SQL and Python KPI results independently reconciled

---

## Key Business Insights

### Customer retention is relatively low

Only around **3% of delivered customers placed two or more delivered orders** within the observable dataset period.

This suggests that most customers appear only once during the historical window.

### Revenue is concentrated geographically

Large Brazilian states such as São Paulo contribute a substantial share of customers and revenue.

### Product performance varies significantly

Some product categories contribute considerably more revenue than others, making category-level analysis useful for merchandising and commercial prioritization.

### Revenue should be interpreted carefully

The dataset provides item price and freight values but does not contain reliable product cost information.

Therefore, this project focuses on **revenue rather than profit or margin**.

### Retention is observational

A customer who does not purchase again in the dataset should not automatically be labelled as churned.

The dataset contains a limited historical window, so retention metrics are interpreted only within that observed period.

---

## Challenges Solved

This project included several real-world data engineering and analytics challenges:

- Debugging MySQL CSV import discrepancies
- Correctly handling standard CSV quoting
- Avoiding join fanout between order items and payments
- Separating order-level and item-level analytical grain
- Building consistent KPI definitions across SQL, Python, and Power BI
- Creating repeat-purchase logic using stable customer identity
- Designing cohort maturity rules to avoid misleading retention comparisons
- Building a star-style Power BI data model

---

## Skills Demonstrated

This project demonstrates practical experience with:

- SQL joins
- CTEs
- Window functions
- Aggregations
- Data quality validation
- Customer segmentation
- Cohort analysis
- Retention analysis
- Revenue analysis
- Python EDA
- Pandas
- Data visualization
- Power BI
- DAX
- Data modelling
- KPI design
- Business analysis
- Git & GitHub
- Technical documentation

---

## Limitations

- The dataset represents Brazilian e-commerce transactions only.
- True product cost is not available, so profitability cannot be calculated reliably.
- Customer churn cannot be confirmed from absence of purchases.
- Retention analysis is limited to the available historical observation period.
- Correlation should not be interpreted as causation.
- Geographic results should not be generalized outside the dataset population.

---

## How to Explore the Project

For SQL analysis, start with:

```text
sql/05_analysis_foundation.sql
sql/06_customer_analysis.sql
sql/07_cohort_retention_analysis.sql
```

For Python analysis:

```text
python/retailpulse_eda.py
```

For the interactive dashboard:

```text
powerbi/RetailPulse.pbix
```

The Power BI Desktop file can be opened locally to explore the dashboard and data model.

---

## Project Status

**Completed**

The complete workflow includes:

- Data validation
- MySQL data layer
- SQL business analysis
- Customer behaviour analysis
- Cohort and retention analysis
- Python EDA
- KPI reconciliation
- Power BI modelling
- DAX measures
- Interactive dashboard
- GitHub documentation

---

## Author

**Ariyan Hussain**

Aspiring Data Analyst | BCA Data Science

Focused on SQL, Python, Power BI, Excel, Statistics, and Business Analytics.
