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

**Phase 8 — Cohort and retention SQL analysis completed and runtime-verified.** The Phase 8 SQL was manually executed against MySQL and successful execution was confirmed by the project owner. KPI definitions are documented in [`docs/RETENTION_KPI_DEFINITIONS.md`](docs/RETENTION_KPI_DEFINITIONS.md). No cohort result values or business findings are published because actual outputs were not provided.

Retention is observed only within the dataset window; absence of purchase does not prove churn. Later cohorts have shorter observation windows, so immature horizons remain `NULL`. Mature-cohort comparisons require sufficient observation time: three complete post-cohort calendar months before the dataset-end month begins. Results should be interpreted descriptively.

The next planned phase is Phase 9 — Python EDA & Statistical Validation. No Python EDA or Power BI work is included in Phase 8.