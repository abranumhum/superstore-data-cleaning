-- 02_quality_checks.sql
-- Simple SELECT counts to find data-quality issues in the raw dirty data.
-- Results are stored in analytics.dq_summary for reporting.
BEGIN;

CREATE TABLE analytics.dq_summary AS
SELECT 'negative_sales' AS defect_type,
       count(*) FILTER (WHERE nullif(trim("Sales"), '') IS NOT NULL
                        AND replace(replace(replace(trim("Sales"), '$', ''), ',', ''), '-', '') ~ '^[0-9]+\.?[0-9]*$'
                        AND trim("Sales") ~ '^-'
                        AND trim("Sales") !~ '^\$') AS issue_count,
       count(*) FILTER (WHERE nullif(trim("Sales"), '') IS NOT NULL
                        AND replace(replace(replace(trim("Sales"), '$', ''), ',', ''), '-', '') ~ '^[0-9]+\.?[0-9]*$'
                        AND trim("Sales") ~ '^-'
                        AND trim("Sales") !~ '^\$') AS detected
FROM raw.orders
UNION ALL
SELECT 'currency_formatted_sales',
       count(*) FILTER (WHERE trim("Sales") LIKE '$_%'),
       count(*) FILTER (WHERE trim("Sales") LIKE '$_%')
FROM raw.orders
UNION ALL
SELECT 'null_customer_name',
       count(*) FILTER (WHERE lower(trim(coalesce("Customer Name", ''))) IN ('', 'null', 'n/a', 'na', 'none')),
       count(*) FILTER (WHERE lower(trim(coalesce("Customer Name", ''))) IN ('', 'null', 'n/a', 'na', 'none'))
FROM raw.orders
UNION ALL
SELECT 'null_postal_code',
       count(*) FILTER (WHERE lower(trim(coalesce("Postal Code", ''))) IN ('', 'null', 'n/a', 'na', 'none')),
       count(*) FILTER (WHERE lower(trim(coalesce("Postal Code", ''))) IN ('', 'null', 'n/a', 'na', 'none'))
FROM raw.orders
UNION ALL
SELECT 'mixed_date_formats',
       count(*) FILTER (WHERE trim("Order Date") ~ '^\d{2}/\d{2}/\d{4}$'
                         OR trim("Ship Date") ~ '^\d{4}/\d{2}/\d{2}$'),
       count(*) FILTER (WHERE trim("Order Date") ~ '^\d{2}/\d{2}/\d{4}$'
                         OR trim("Ship Date") ~ '^\d{4}/\d{2}/\d{2}$')
FROM raw.orders
UNION ALL
SELECT 'whitespace_case_labels',
       count(*) FILTER (WHERE trim("Ship Mode") != "Ship Mode"
                         OR trim("Category") != "Category"
                         OR trim("Region") != "Region"
                         OR "Ship Mode" = lower("Ship Mode")
                         OR "Category" = lower("Category")
                         OR "Region" = lower("Region")),
       count(*) FILTER (WHERE trim("Ship Mode") != "Ship Mode"
                         OR trim("Category") != "Category"
                         OR trim("Region") != "Region"
                         OR "Ship Mode" = lower("Ship Mode")
                         OR "Category" = lower("Category")
                         OR "Region" = lower("Region"))
FROM raw.orders
UNION ALL
SELECT 'malformed_order_id',
       count(*) FILTER (WHERE upper(trim("Order ID")) !~ '^[A-Z]{2}-[0-9]{4}-[0-9]+$'),
       count(*) FILTER (WHERE upper(trim("Order ID")) !~ '^[A-Z]{2}-[0-9]{4}-[0-9]+$')
FROM raw.orders
UNION ALL
SELECT 'malformed_customer_id',
       count(*) FILTER (WHERE upper(trim("Customer ID")) !~ '^[A-Z]{2}-[0-9]+$'),
       count(*) FILTER (WHERE upper(trim("Customer ID")) !~ '^[A-Z]{2}-[0-9]+$')
FROM raw.orders
UNION ALL
SELECT 'malformed_product_id',
       count(*) FILTER (WHERE upper(trim("Product ID")) !~ '^.{2,}-.{2}-[0-9]+$'),
       count(*) FILTER (WHERE upper(trim("Product ID")) !~ '^.{2,}-.{2}-[0-9]+$')
FROM raw.orders
UNION ALL
SELECT 'duplicate_rows',
       count(*) - count(DISTINCT "Row ID"),
       count(*) - count(DISTINCT "Row ID")
FROM raw.orders;

COMMIT;
