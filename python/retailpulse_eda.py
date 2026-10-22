r"""RetailPulse Phase 9 descriptive EDA from original Olist CSVs.
Run at repository root: .venv\Scripts\python.exe python\retailpulse_eda.py
This independently reproduces approved SQL definitions from CSVs; no MySQL or writes to source data.
"""
from pathlib import Path
import json, math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
CHARTS = ROOT / "images" / "python"
CHARTS.mkdir(parents=True, exist_ok=True)

def load_csv(name, **kwargs):
    path = RAW / name
    if not path.is_file():
        raise FileNotFoundError(f"Required CSV not found: {path}")
    return pd.read_csv(path, **kwargs)

def save(fig, name):
    fig.tight_layout()
    fig.savefig(CHARTS / name, dpi=160, bbox_inches="tight")
    plt.close(fig)

def main():
    customers = load_csv("olist_customers_dataset.csv", dtype={"customer_id":"string","customer_unique_id":"string"})
    orders = load_csv("olist_orders_dataset.csv", dtype={"order_id":"string","customer_id":"string"}, parse_dates=["order_purchase_timestamp"])
    items = load_csv("olist_order_items_dataset.csv", dtype={"order_id":"string","product_id":"string"})
    products = load_csv("olist_products_dataset.csv", dtype={"product_id":"string"})
    translations = load_csv("product_category_name_translation.csv", dtype="string")

    print("SOURCE INSPECTION: shape, dtypes, null counts, duplicate counts, sample rows")
    for name, frame in {"customers":customers,"orders":orders,"order_items":items,"products":products,"translations":translations}.items():
        print(f"\n{name}: shape={frame.shape}; full-row duplicates={int(frame.duplicated().sum())}")
        print("dtypes:", frame.dtypes.astype(str).to_dict())
        print("null counts:", frame.isna().sum().to_dict())
        print(frame.head(3).to_string(index=False))

    keys = [(customers,["customer_id"],"customers.customer_id"),
            (orders,["order_id"],"orders.order_id"),
            (items,["order_id","order_item_id"],"order_items composite key"),
            (products,["product_id"],"products.product_id"),
            (translations,["product_category_name"],"translation category")]
    for frame, cols, label in keys:
        duplicate_count = int(frame.duplicated(cols).sum())
        print(f"Key duplicate rows for {label}: {duplicate_count}")
        if duplicate_count:
            raise ValueError(f"Duplicate key found: {label}")
    if not items.order_id.isin(set(orders.order_id)).all():
        raise ValueError("Order-item rows reference order IDs absent from orders.")
    if not items.product_id.isin(set(products.product_id)).all():
        raise ValueError("Order-item rows reference product IDs absent from products.")

    items["price"] = pd.to_numeric(items["price"], errors="raise")
    items["freight_value"] = pd.to_numeric(items["freight_value"], errors="raise")
    orders["order_purchase_timestamp"] = pd.to_datetime(orders["order_purchase_timestamp"], errors="raise")
    joined = orders.merge(customers[["customer_id","customer_unique_id","customer_state"]],
                          on="customer_id", how="left", validate="one_to_one", indicator=True)
    unmatched = int(joined["_merge"].ne("both").sum())
    if unmatched:
        raise ValueError(f"{unmatched} orders failed customer join.")
    delivered = joined.loc[joined.order_status.eq("delivered")].drop(columns="_merge").copy()
    delivered["purchase_date"] = delivered.order_purchase_timestamp.dt.normalize()
    delivered["purchase_month"] = delivered.order_purchase_timestamp.dt.to_period("M")
    lines = items.merge(delivered[["order_id","customer_unique_id","customer_state","order_purchase_timestamp","purchase_date","purchase_month"]],
                        on="order_id", how="inner", validate="many_to_one")
    if (lines.price < 0).any():
        raise ValueError("Negative delivered item price found; inspect before interpreting.")
    item_revenue = lines.groupby("order_id", observed=True).price.sum()
    order_metrics = delivered.merge(item_revenue.rename("order_revenue"), left_on="order_id", right_index=True,
                                    how="left", validate="one_to_one")
    order_metrics["order_revenue"] = order_metrics.order_revenue.fillna(0.0)
    item_counts = lines.groupby("order_id", observed=True).size()
    order_metrics["item_count"] = order_metrics.order_id.map(item_counts).fillna(0).astype("int64")

    first_ts, last_ts = delivered.order_purchase_timestamp.min(), delivered.order_purchase_timestamp.max()
    if pd.isna(first_ts) or pd.isna(last_ts):
        raise ValueError("No valid delivered purchase timestamps.")
    delivered_orders_n = int(delivered.order_id.nunique())
    delivered_customers_n = int(delivered.customer_unique_id.nunique())
    revenue = float(lines.price.sum())
    aov = float(order_metrics.order_revenue.mean())

    monthly = order_metrics.groupby("purchase_month", observed=True).agg(
        revenue=("order_revenue","sum"), orders=("order_id","nunique"))
    months = pd.period_range(monthly.index.min(), monthly.index.max(), freq="M")
    existing_months = set(monthly.index)
    missing_months = [str(m) for m in months if m not in existing_months]
    monthly = monthly.reindex(months, fill_value=0)
    first_partial = first_ts.date() != first_ts.to_period("M").start_time.date()
    last_partial = last_ts.date() != last_ts.to_period("M").end_time.date()
    full_monthly = monthly.copy()
    if first_partial:
        full_monthly = full_monthly.iloc[1:]
    if last_partial and len(full_monthly):
        full_monthly = full_monthly.iloc[:-1]
    best_full_month = str(full_monthly.revenue.idxmax()) if len(full_monthly) else "not available"
    best_full_month_revenue = float(full_monthly.revenue.max()) if len(full_monthly) else float("nan")
    full_month_changes = full_monthly.revenue.pct_change(fill_method=None).replace([np.inf, -np.inf], np.nan).dropna()
    largest_full_month_increase = float(full_month_changes.max()) if len(full_month_changes) else float("nan")
    largest_full_month_drop = float(full_month_changes.min()) if len(full_month_changes) else float("nan")
    full_month_delta = full_monthly.revenue.diff().dropna()
    increase_month = str(full_month_delta.idxmax()) if len(full_month_delta) else "not available"
    decrease_month = str(full_month_delta.idxmin()) if len(full_month_delta) else "not available"
    increase_amount = float(full_month_delta.max()) if len(full_month_delta) else float("nan")
    decrease_amount = float(full_month_delta.min()) if len(full_month_delta) else float("nan")

    cs = order_metrics.groupby("customer_unique_id", dropna=False).agg(
        delivered_orders=("order_id","nunique"), total_revenue=("order_revenue","sum"),
        first_purchase=("order_purchase_timestamp","min"), last_purchase=("order_purchase_timestamp","max")).reset_index()
    cs["average_order_value"] = cs.total_revenue / cs.delivered_orders
    cs["frequency_bucket"] = pd.cut(cs.delivered_orders, [0,1,2,3,4,np.inf],
                                    labels=["1 order","2 orders","3 orders","4 orders","5+ orders"])
    repeat_n = int(cs.delivered_orders.ge(2).sum())
    repeat_pct = 100.0 * repeat_n / len(cs)

    ordered = order_metrics.sort_values(["customer_unique_id","order_purchase_timestamp","order_id"]).copy()
    ordered["previous_date"] = ordered.groupby("customer_unique_id").purchase_date.shift()
    gaps = (ordered.purchase_date - ordered.previous_date).dt.days.dropna()
    average_gap_days = float(gaps.mean()) if len(gaps) else float("nan")
    median_gap_days = float(gaps.median()) if len(gaps) else float("nan")

    # Cohort month is the first delivered purchase month; active grain is customer-month.
    cs["cohort_month"] = cs.first_purchase.dt.to_period("M")
    activity = order_metrics[["customer_unique_id","purchase_month"]].drop_duplicates().merge(
        cs[["customer_unique_id","cohort_month"]], on="customer_unique_id", validate="many_to_one")
    activity["month_number"] = ((activity.purchase_month.dt.year-activity.cohort_month.dt.year)*12
                                + activity.purchase_month.dt.month-activity.cohort_month.dt.month)
    if (activity.month_number < 0).any():
        raise ValueError("Negative cohort month offset found.")
    sizes = cs.groupby("cohort_month").customer_unique_id.nunique()
    cohort = activity.groupby(["cohort_month","month_number"]).customer_unique_id.nunique().rename("active_customers").reset_index()
    cohort["cohort_size"] = cohort.cohort_month.map(sizes)
    cohort["retention_rate"] = cohort.active_customers/cohort.cohort_size
    month0 = cohort.loc[cohort.month_number.eq(0),"retention_rate"]
    cohort_checks = {"month_0_100_percent":bool(np.allclose(month0,1.0)),
                     "retention_at_most_100_percent":bool((cohort.retention_rate<=1.0).all()),
                     "no_negative_months":bool((cohort.month_number>=0).all()),
                     "positive_cohort_sizes":bool((cohort.cohort_size>0).all())}
    if not all(cohort_checks.values()):
        raise ValueError(f"Cohort validation failed: {cohort_checks}")

    freq = cs.frequency_bucket.value_counts(sort=False).reindex(["1 order","2 orders","3 orders","4 orders","5+ orders"],fill_value=0)
    category = lines.merge(products[["product_id","product_category_name"]],on="product_id",how="left",validate="many_to_one")
    category = category.merge(translations,on="product_category_name",how="left",validate="many_to_one")
    untranslated_sales_lines = int(category.product_category_name_english.isna().sum())
    category["category"] = category.product_category_name_english.combine_first(category.product_category_name).fillna("Unknown")
    category_summary = category.groupby("category",dropna=False).agg(
        revenue=("price","sum"),orders=("order_id","nunique"),items=("order_id","size")).reset_index()
    top_cat = category_summary.sort_values(["revenue","category"],ascending=[False,True]).head(10)
    bottom_cat = category_summary.sort_values(["revenue","category"],ascending=[True,True]).head(10)
    state = order_metrics.groupby("customer_state",dropna=False).agg(
        revenue=("order_revenue","sum"),orders=("order_id","nunique"),
        customers=("customer_unique_id","nunique"),aov=("order_revenue","mean")).reset_index().sort_values("revenue",ascending=False)

    order_stats = order_metrics.order_revenue.describe(percentiles=[.25,.5,.75,.9,.95,.99])
    cust_stats = cs.total_revenue.describe(percentiles=[.25,.5,.75,.9,.95,.99])
    skew = float(cs.total_revenue.skew())
    q1,q3 = order_metrics.order_revenue.quantile([.25,.75])
    low,high = float(q1-1.5*(q3-q1)),float(q3+1.5*(q3-q1))
    outlier_mask = order_metrics.order_revenue.lt(low)|order_metrics.order_revenue.gt(high)
    outliers = order_metrics.loc[outlier_mask,["order_id","order_revenue","item_count"]].nlargest(10,"order_revenue").copy()
    outliers["classification"] = "needs manual review"
    outlier_examples = "; ".join(
        f"{row.order_id}: {row.order_revenue:.2f} revenue / {int(row.item_count)} item lines"
        for row in outliers.head(5).itertuples(index=False)
    )
    top_n = max(1,math.ceil(len(cs)*.10))
    concentration_order = cs.sort_values(["total_revenue","customer_unique_id"],ascending=[False,True])
    top_share = float(concentration_order.head(top_n).total_revenue.sum()/cs.total_revenue.sum())
    corr_price_freight = float(lines[["price","freight_value"]].corr().iloc[0,1])
    corr_order_items = float(order_metrics[["order_revenue","item_count"]].corr().iloc[0,1])

    # Readable, labeled charts. All observations are retained.
    fig,ax=plt.subplots(figsize=(11,5)); ax.plot(monthly.index.astype(str),monthly.revenue,marker="o")
    ax.set(title="Monthly Delivered Item-Price Revenue",xlabel="Purchase month",ylabel="Revenue (dataset currency)")
    ax.tick_params(axis="x",rotation=60); ax.grid(axis="y",alpha=.25); save(fig,"monthly_revenue.png")
    fig,ax=plt.subplots(figsize=(11,5)); ax.plot(monthly.index.astype(str),monthly.orders,marker="o",color="#2878B5")
    ax.set(title="Monthly Delivered Order Count",xlabel="Purchase month",ylabel="Delivered orders")
    ax.tick_params(axis="x",rotation=60); ax.grid(axis="y",alpha=.25); save(fig,"monthly_delivered_orders.png")
    fig,axes=plt.subplots(1,2,figsize=(11,5)); axes[0].hist(order_metrics.order_revenue,bins=60,color="#2878B5",edgecolor="white")
    axes[0].set(title="Order Revenue Distribution",xlabel="Delivered item-price revenue per order",ylabel="Order count")
    axes[1].boxplot(order_metrics.order_revenue,showfliers=True); axes[1].set(title="Box Plot (outliers retained)",ylabel="Revenue per delivered order")
    save(fig,"order_revenue_distribution.png")
    fig,ax=plt.subplots(figsize=(9,5)); ax.hist(cs.total_revenue,bins=60,color="#4C956C",edgecolor="white")
    ax.set(title="Delivered Customer Revenue Distribution",xlabel="Customer item-price revenue",ylabel="Customer count"); save(fig,"customer_revenue_distribution.png")
    fig,ax=plt.subplots(figsize=(10,6)); p=top_cat.sort_values("revenue"); ax.barh(p.category,p.revenue,color="#2878B5")
    ax.set(title="Top 10 Categories by Delivered Revenue",xlabel="Revenue (dataset currency)",ylabel="Category label"); save(fig,"top_categories_revenue.png")
    fig,ax=plt.subplots(figsize=(10,6)); p=state.head(10).sort_values("revenue"); ax.barh(p.customer_state.astype(str),p.revenue,color="#6A4C93")
    ax.set(title="Top 10 Customer States by Delivered Revenue",xlabel="Revenue (dataset currency)",ylabel="Customer state"); save(fig,"revenue_by_state.png")
    fig,ax=plt.subplots(figsize=(8,5)); ax.bar(freq.index.astype(str),freq.values,color="#2878B5")
    ax.set(title="Delivered Purchase Frequency per Customer",xlabel="Delivered orders per customer",ylabel="Customer count"); ax.tick_params(axis="x",rotation=20); save(fig,"purchase_frequency.png")
    fig,ax=plt.subplots(figsize=(9,5))
    if len(gaps): ax.hist(gaps,bins=50,color="#D17A22",edgecolor="white")
    ax.set(title="Days Between Consecutive Delivered Purchases",xlabel="Calendar days",ylabel="Purchase intervals"); save(fig,"days_between_purchases.png")

    kpis = pd.DataFrame([
        ["Delivered order count",delivered_orders_n,"sql/05_analysis_foundation.sql","Definition reproduced; SQL numeric output unavailable"],
        ["Unique delivered customers",delivered_customers_n,"sql/05_analysis_foundation.sql","Definition reproduced; SQL numeric output unavailable"],
        ["Total delivered item revenue",revenue,"sql/05_analysis_foundation.sql","Definition reproduced; SQL numeric output unavailable"],
        ["Average order value",aov,"sql/05_analysis_foundation.sql","Definition reproduced; SQL numeric output unavailable"],
        ["Monthly revenue",f"{len(monthly)} calendar-month series","sql/05_analysis_foundation.sql","Definition reproduced; SQL numeric output unavailable"],
        ["Repeat customer rate",repeat_pct,"sql/06_customer_analysis.sql","Definition reproduced; SQL numeric output unavailable"],
        ["Second purchase rate",repeat_pct,"sql/07_cohort_retention_analysis.sql","Same delivered customer 2+ order definition; SQL output unavailable"],
    ],columns=["metric","python_value","sql_definition_reference","validation_status"])
    kpis.to_csv(ROOT/"python"/"eda_kpi_validation.csv",index=False)

    print("\nPYTHON KPI VALUES\n",kpis.to_string(index=False))
    print("\nORDER REVENUE STATS\n",order_stats.to_string())
    print("\nCUSTOMER REVENUE STATS\n",cust_stats.to_string())
    print("\nCUSTOMER REVENUE SKEWNESS:",skew)
    print("\nMONTHLY REVENUE AND ORDERS\n",monthly.to_string())
    print("Missing months:",missing_months,"partial first/last:",first_partial,last_partial)
    print("\nCOHORT CHECKS:",cohort_checks)
    print("\nTOP CATEGORIES\n",top_cat.to_string(index=False))
    print("\nBOTTOM CATEGORIES WITH COUNTS\n",bottom_cat.to_string(index=False))
    print("\nSTATE SUMMARY (top 10)\n",state.head(10).to_string(index=False))
    print(f"\nIQR fences: {low:.2f}, {high:.2f}; flagged count={int(outlier_mask.sum())}; no rows removed")
    print(outliers.to_string(index=False))
    print(f"Top 10% customer revenue share: {top_share:.6%}")
    print(f"Correlations: item price/freight={corr_price_freight:.6f}; order revenue/item count={corr_order_items:.6f}")
    print("Association does not establish causality.")
    print("Charts:",*[p.name for p in sorted(CHARTS.glob("*.png"))],sep="\n  ")

    notes = [
        "# RetailPulse Python EDA Notes","",
        "## Method","",
        "From the project root: create an environment with py -m venv .venv; install dependencies with .venv\\Scripts\\python.exe -m pip install -r python\\requirements-eda.txt; run with .venv\\Scripts\\python.exe python\\retailpulse_eda.py. Dependencies are pandas, numpy, and matplotlib. No Jupyter runtime was available, so this standalone script runs the analysis and saves its charts and notes. It reads original CSVs in data/raw and independently reproduces SQL definitions; it does not connect to MySQL or modify CSVs. Delivered orders define completed purchases; customer identity is customer_unique_id joined through customer_id. Revenue is SUM(order_items.price); freight and payments are excluded. Item lines are aggregated to order grain before customer/order metrics. SQL result files were unavailable, so no numerical SQL equality is claimed.","",
        "## FACT — outputs from this run","",
        f"- Source rows: customers {len(customers):,}; orders {len(orders):,}; items {len(items):,}; products {len(products):,}; translations {len(translations):,}.",
        f"- Delivered orders {delivered_orders_n:,}; unique delivered customers {delivered_customers_n:,}; delivered item-price revenue {revenue:,.2f}; average order value {aov:,.2f}.",
        f"- Timestamp range {first_ts} through {last_ts}; monthly periods {len(monthly)}; missing internal months {len(missing_months)}; first/last months partial {first_partial}/{last_partial}.",
        f"- Repeat customers {repeat_n:,} of {len(cs):,}; repeat rate {repeat_pct:.4f}%. Frequency buckets: {freq.to_dict()}.",
        f"- Consecutive purchase interval count {len(gaps):,}; average {average_gap_days:.2f} days; median {median_gap_days:.2f} days.",
        f"- Customer revenue mean/median/std/min/Q1/Q3/max: {cust_stats['mean']:.2f}/{cust_stats['50%']:.2f}/{cust_stats['std']:.2f}/{cust_stats['min']:.2f}/{cust_stats['25%']:.2f}/{cust_stats['75%']:.2f}/{cust_stats['max']:.2f}.",
        f"- Highest-revenue full observed month (excluding partial endpoints): {best_full_month}, {best_full_month_revenue:,.2f}.",
        f"- Largest adjacent full-month revenue increase: {increase_month}, +{increase_amount:,.2f}; largest decrease: {decrease_month}, {decrease_amount:,.2f}.",
        f"- Highest-revenue category: {top_cat.iloc[0]['category']}, {top_cat.iloc[0]['revenue']:,.2f} revenue, {int(top_cat.iloc[0]['orders']):,} orders, {int(top_cat.iloc[0]['items']):,} item lines.",
        f"- Highest-revenue customer state: {state.iloc[0]['customer_state']}, {state.iloc[0]['revenue']:,.2f} revenue across {int(state.iloc[0]['orders']):,} orders and {int(state.iloc[0]['customers']):,} delivered customers.",
        f"- Item lines without English category translation (source fallback used): {untranslated_sales_lines:,}.",
        f"- Order revenue count/mean/median/std/min/Q1/Q3/max: {order_stats['count']:.0f}/{order_stats['mean']:.2f}/{order_stats['50%']:.2f}/{order_stats['std']:.2f}/{order_stats['min']:.2f}/{order_stats['25%']:.2f}/{order_stats['75%']:.2f}/{order_stats['max']:.2f}.",
        f"- Customer revenue skewness {skew:.4f}; top 10% of customers by count contribute {top_share:.4%} of delivered customer revenue.",
        f"- Cohort validation checks: {json.dumps(cohort_checks,sort_keys=True)}; month-zero cohort rows checked {len(month0):,}.",
        f"- IQR fences {low:.2f} and {high:.2f}; flagged orders {int(outlier_mask.sum()):,}; top flagged examples (all need manual review): {outlier_examples}.",
        f"- Lowest-revenue category: {bottom_cat.iloc[0]['category']}, {bottom_cat.iloc[0]['revenue']:,.2f} over {int(bottom_cat.iloc[0]['orders']):,} orders and {int(bottom_cat.iloc[0]['items']):,} item lines; low volume is context, not a failure label.",
        f"- Correlations: item price/freight {corr_price_freight:.4f}; order revenue/item count {corr_order_items:.4f}.",
        "- SQL/Python numerical cross-check: unavailable because SQL result outputs were not provided.","",
        "## INTERPRETATION — descriptive only","",
        f"Mean order revenue is {'above' if order_stats['mean']>order_stats['50%'] else 'not above'} the median; this describes the observed distribution, not its cause. Skewness and top-decile contribution summarize concentration but do not imply that high-revenue customers are inherently better. No causal conclusion or recommendation is made.","",
        "Any correlations are descriptive. Association does not establish causality. No hypothesis tests, churn labels, profit calculations, predictive models, or recommendations are included.","",
        "## Outlier approach","",
        f"Order revenue is flagged using Tukey fences: below Q1 - 1.5 x IQR ({low:.2f}) or above Q3 + 1.5 x IQR ({high:.2f}). All current IQR flags are classified as needing manual review until source rows and business context are checked. After review, a structurally sound plausible value may be classified as a valid extreme observation; invalid numbers or broken keys may be classified as possible data-quality issues. No observations are removed or winsorized; charts include all orders.","",
        "## Checks and caveats","",
        f"Orders unmatched to customers: {unmatched}. Item rows with missing parent orders/products were checked and none were found. Key uniqueness checks passed for customer_id, order_id, (order_id, order_item_id), product_id, and translation category. Negative item prices: {int((items.price<0).sum())}; zero prices: {int((items.price==0).sum())}.",
        "Monthly gaps are filled with zero for charting. The first and last observed calendar months can be partial. Category label fallback matches SQL: English translation, source category, then Unknown. State AOV is the mean of one revenue total per delivered order.",
        "Cohort month is first delivered purchase month; activity is distinct customer-month; month indexing uses calendar-month arithmetic. Checks cover month 0 at 100%, no retention above 100%, nonnegative indexes, and positive cohort sizes.",
        "This Python run uses raw CSVs, not imported MySQL tables. The approved definitions were followed, but numeric equality with SQL outputs was not established. Olist is historical and incomplete beyond its observation window; absence of purchase is not churn. Freight is not seller cost and the data has no profit field.","",
        "## Charts","",
        "Generated charts are in images/python: monthly revenue, monthly delivered order count, order revenue histogram and box plot, customer revenue, top categories, customer-state revenue, purchase frequency, and days between purchases.","",
    ]
    (ROOT/"docs"/"PYTHON_EDA_NOTES.md").write_text("\n".join(notes),encoding="utf-8")
    print("Wrote docs/PYTHON_EDA_NOTES.md and python/eda_kpi_validation.csv")

if __name__ == "__main__":
    main()
