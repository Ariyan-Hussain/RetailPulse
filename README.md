# RetailPulse

## E-Commerce Revenue, Customer Behaviour & Retention Analytics

### Project Overview

RetailPulse is an end-to-end Data Analyst portfolio project focused on analysing e-commerce transaction data and turning the analysis into useful business insights. The planned work will use SQL, Excel, Python, and Power BI to study revenue, products, customers, regions, repeat purchases, and retention.

### Business Problem

RetailPulse analyses e-commerce transactions to understand revenue, product performance, customer purchasing patterns, regional patterns, repeat purchases, and retention. Any findings and recommendations will be based on the data and documented limitations.

### Project Objectives

- Measure overall revenue performance.
- Identify top-performing and underperforming products.
- Analyse regional performance.
- Understand customer purchasing behaviour.
- Identify repeat customers.
- Assess cohort and retention analysis feasibility using the available customer identifiers and dates.
- Calculate meaningful business KPIs.
- Translate analytical findings into realistic business recommendations.

### Key Analytical Areas

- Revenue Analytics
- Product Analytics
- Customer Analytics
- Regional Analytics
- Repeat Purchase Analytics
- Retention Analytics

### Dataset limitation

The selected Olist dataset does not contain true seller cost or profit data, so profitability metrics are intentionally excluded. Freight value represents freight charged in the transaction and must not be interpreted as seller shipping cost. The project will not claim churn or causation from these data.

### Dataset source

Brazilian E-Commerce Public Dataset by Olist: [official Kaggle dataset page](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). The original CSV filenames are retained in `data/raw/`.

### Planned Technology Stack

- MySQL
- Excel
- Python
- Pandas
- Matplotlib
- Power BI
- Git
- GitHub

### Planned Workflow

Raw Dataset → Data Understanding → Data Quality Audit → Data Cleaning → MySQL → SQL Analysis → Python EDA → Customer Analysis → Retention Analysis → Power BI → Business Insights → Recommendations

### Repository Structure

Dataset inspection documents: `docs/DATA_DICTIONARY.md`, `docs/DATA_MODEL_NOTES.md`, and `docs/DATA_QUALITY_AUDIT.md`. Phase 4 planning documents: `docs/DATA_CLEANING_STRATEGY.md` and `docs/MYSQL_SCHEMA_DESIGN.md`.

```text
RetailPulse/
├── README.md
├── .gitignore
├── data/
│   ├── raw/
│   └── cleaned/
├── sql/
├── python/
├── powerbi/
├── images/
└── docs/
    ├── PROJECT_SCOPE.md
    └── DATASET_REQUIREMENTS.md
```

Raw Olist CSV files are stored locally under `data/raw/` and excluded from Git by `.gitignore`. The `.gitkeep` placeholder remains trackable. The initial dataset inspection is documented in `docs/DATA_DICTIONARY.md`, `docs/DATA_MODEL_NOTES.md`, and `docs/DATA_QUALITY_AUDIT.md`. SQL analysis foundations are documented in `sql/05_analysis_foundation.sql` and `docs/KPI_DEFINITIONS.md`; Python EDA and Power BI reporting have not started.

### Current Project Status

**Phase 7 — Advanced customer and repeat-purchase SQL analysis completed and runtime-verified.** The Phase 7 SQL was manually executed against MySQL and the project owner confirmed successful execution. Definitions are documented in [`docs/CUSTOMER_KPI_DEFINITIONS.md`](docs/CUSTOMER_KPI_DEFINITIONS.md). No query results or business findings are published here because no actual outputs were provided.

The Phase 7 analysis is descriptive and uses delivered orders as the completed-purchase population. It does not claim churn, causation, profit, or business recommendations. The next planned phase is Phase 8 — Cohort & Retention Analysis. Python EDA and Power BI reporting remain future work.