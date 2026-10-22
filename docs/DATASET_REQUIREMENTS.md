# Dataset Requirements

## Required or Strongly Preferred Columns

### Customer

- `customer_id`

### Orders

- `order_id`
- `order_date`

### Products

- `product_id`
- `product_name`
- `category`
- `subcategory` (if available)

### Transactions

- `quantity`
- `unit_price` or `revenue`/`sales`

### Location

- `city`
- `state`
- `region`
- `country` or a similar geographic field

### Original Selection Preferences

- `profit`
- `cost`
- `discount`

These were initial dataset-selection preferences, not mandatory project fields. The selected Olist dataset does not provide true seller cost or profit data; profitability analysis is therefore out of scope. Do not derive a fake cost or profit value from freight.

### Optional

- Payment method
- Sales channel
- Customer segment
- Shipping information

## Dataset Suitability

The dataset should:

- Contain enough rows for meaningful analysis.
- Include many customers and orders.
- Cover several products or categories.
- Span enough time for monthly trend analysis.
- Support SQL business questions and Power BI reporting.
- Preferably support customer retention analysis.
- Preferably contain realistic data-quality issues to investigate.
- Allow normalization into multiple tables if useful.

## Reject or Reconsider Datasets That

- Are extremely small.
- Are already highly aggregated.
- Are designed mainly for machine learning rather than business analysis.
- Have no dates.
- Lack customer identifiers when customer analysis is required.
- Cannot support meaningful revenue analysis.
- Contain only 3–4 simple columns.
- Are synthetic without a strong justification.

Dataset suitability was confirmed through the initial inspection documented in `DATA_DICTIONARY.md` and `DATA_QUALITY_AUDIT.md`. The selected dataset is the Brazilian E-Commerce Public Dataset by Olist.
