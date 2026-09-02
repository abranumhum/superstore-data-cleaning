-- 04_analysis.sql
-- Business metrics and dirty-vs-clean reconciliation.
BEGIN;

-- 1. KPI summary table
CREATE TABLE analytics.kpi_summary AS
SELECT
    count(*)::integer AS total_orders,
    count(DISTINCT customer_id)::integer AS unique_customers,
    round(sum(sales), 2) AS total_sales,
    round(sum(profit), 2) AS total_profit,
    round(100 * sum(profit) / nullif(sum(sales), 0), 2) AS profit_margin_pct,
    round(avg(sales), 2) AS average_order_value,
    sum(quantity)::integer AS total_units_sold,
    round(avg(ship_date - order_date), 1) AS avg_fulfillment_days
FROM analytics.clean_orders;

-- 2. Sales performance by region
CREATE TABLE analytics.sales_by_region AS
SELECT
    region,
    count(*)::integer AS orders,
    round(sum(sales), 2) AS total_sales,
    round(sum(profit), 2) AS total_profit,
    round(100 * sum(profit) / nullif(sum(sales), 0), 2) AS profit_margin_pct
FROM analytics.clean_orders
GROUP BY region
ORDER BY total_sales DESC;

-- 3. Profitability by category
CREATE TABLE analytics.profitability_by_category AS
SELECT
    category,
    sub_category,
    count(*)::integer AS orders,
    round(sum(sales), 2) AS total_sales,
    round(sum(profit), 2) AS total_profit,
    round(100 * sum(profit) / nullif(sum(sales), 0), 2) AS profit_margin_pct,
    round(avg(discount) * 100, 1) AS avg_discount_pct
FROM analytics.clean_orders
GROUP BY category, sub_category
ORDER BY total_profit ASC;

-- 4. Top 10 products by sales
CREATE TABLE analytics.top_products AS
SELECT
    product_name,
    sub_category,
    count(*)::integer AS orders,
    round(sum(sales), 2) AS total_sales,
    round(sum(profit), 2) AS total_profit
FROM analytics.clean_orders
GROUP BY product_name, sub_category
ORDER BY total_sales DESC
LIMIT 10;

-- 5. Discount impact on profitability
CREATE TABLE analytics.discount_performance AS
SELECT
    CASE
        WHEN discount = 0 THEN 'No discount'
        WHEN discount <= 0.10 THEN 'Low (0-10%)'
        WHEN discount <= 0.20 THEN 'Medium (10-20%)'
        ELSE 'High (>20%)'
    END AS discount_band,
    count(*)::integer AS line_items,
    round(sum(sales), 2) AS total_sales,
    round(sum(profit), 2) AS total_profit,
    round(100 * sum(profit) / nullif(sum(sales), 0), 2) AS profit_margin_pct
FROM analytics.clean_orders
GROUP BY 1
ORDER BY min(discount);

-- 6. Monthly sales trend
CREATE TABLE analytics.monthly_trend AS
SELECT
    to_char(order_date, 'YYYY-MM') AS month,
    count(*)::integer AS orders,
    round(sum(sales), 2) AS total_sales,
    round(sum(profit), 2) AS total_profit
FROM analytics.clean_orders
GROUP BY to_char(order_date, 'YYYY-MM')
ORDER BY month;

-- 7. Dirty vs Clean reconciliation
CREATE TABLE analytics.business_summary AS
SELECT
    metric_name,
    dirty_value,
    clean_value,
    round(dirty_value - clean_value, 2) AS absolute_impact,
    round(100 * (dirty_value - clean_value) / nullif(clean_value, 0), 2) AS relative_impact_pct
FROM (
    SELECT
        'total_sales' AS metric_name,
        sum(replace(replace("Sales", '$', ''), ',', '')::numeric(14,4)) AS dirty_value,
        (SELECT sum(sales) FROM analytics.clean_orders) AS clean_value
    FROM raw.orders
    WHERE replace(replace("Sales", '$', ''), ',', '') ~ '^-?[0-9]+\.?[0-9]*$'
    UNION ALL
    SELECT 'total_units_sold',
           sum("Quantity"::numeric),
           (SELECT sum(quantity) FROM analytics.clean_orders)
    FROM raw.orders
    WHERE "Quantity" ~ '^-?[0-9]+$'
    UNION ALL
    SELECT 'total_profit',
           sum(replace(replace("Profit", '$', ''), ',', '')::numeric(14,4)),
           (SELECT sum(profit) FROM analytics.clean_orders)
    FROM raw.orders
    WHERE replace(replace("Profit", '$', ''), ',', '') ~ '^-?[0-9]+\.?[0-9]*$'
) reconciliation
ORDER BY metric_name;

COMMIT;
