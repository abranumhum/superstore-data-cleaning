-- 03_cleaning.sql
-- Clean the dirty data using basic SQL expressions.
-- No custom functions — just TRIM, UPPER, REPLACE, CASE, ROW_NUMBER, regex.
-- Rows that fail basic parsing are simply excluded (WHERE clause filters).
BEGIN;

CREATE TABLE analytics.clean_orders AS
WITH parsed AS (
    SELECT
        row_number() OVER (PARTITION BY "Row ID"::bigint ORDER BY "Row ID") AS rn,
        "Row ID"::bigint AS row_id,
        upper(trim("Order ID")) AS order_id,
        -- Handle two date formats: YYYY-MM-DD and MM/DD/YYYY
        CASE
            WHEN trim("Order Date") ~ '^\d{4}-\d{2}-\d{2}$'
                THEN to_date("Order Date", 'YYYY-MM-DD')
            WHEN trim("Order Date") ~ '^\d{2}/\d{2}/\d{4}$'
                THEN to_date("Order Date", 'MM/DD/YYYY')
            ELSE NULL
        END AS order_date,
        CASE
            WHEN trim("Ship Date") ~ '^\d{4}-\d{2}-\d{2}$'
                THEN to_date("Ship Date", 'YYYY-MM-DD')
            WHEN trim("Ship Date") ~ '^\d{4}/\d{2}/\d{2}$'
                THEN to_date("Ship Date", 'YYYY/MM/DD')
            ELSE NULL
        END AS ship_date,
        initcap(trim("Ship Mode")) AS ship_mode,
        upper(trim("Customer ID")) AS customer_id,
        trim("Customer Name") AS customer_name,
        initcap(trim("Segment")) AS segment,
        trim("Country/Region") AS country_region,
        trim("City") AS city,
        trim("State/Province") AS state_province,
        regexp_replace(trim("Postal Code"), '\.0$', '') AS postal_code,
        initcap(trim("Region")) AS region,
        upper(trim("Product ID")) AS product_id,
        initcap(trim("Category")) AS category,
        trim("Sub-Category") AS sub_category,
        trim("Product Name") AS product_name,
        abs(replace(replace("Sales", '$', ''), ',', '')::numeric(14,4)) AS sales,
        abs("Quantity"::numeric)::integer AS quantity,
        abs("Discount"::numeric(6,4)) AS discount,
        replace(replace("Profit", '$', ''), ',', '')::numeric(14,4) AS profit
    FROM raw.orders
    -- Only rows where core fields parse correctly
    WHERE "Row ID" IS NOT NULL
      AND trim("Row ID"::text) ~ '^[0-9]+$'
      AND trim(replace(replace("Sales", '$', ''), ',', '')) ~ '^-?[0-9]+\.?[0-9]*$'
      AND trim("Quantity") ~ '^-?[0-9]+$'
      AND trim("Discount") ~ '^-?[0-9]+\.?[0-9]*$'
      AND trim(replace(replace("Profit", '$', ''), ',', '')) ~ '^-?[0-9]+\.?[0-9]*$'
)
SELECT
    row_id, order_id, order_date, ship_date, ship_mode,
    customer_id, customer_name, segment, country_region, city,
    state_province, postal_code, region, product_id, category,
    sub_category, product_name, sales, quantity, discount, profit
FROM parsed
WHERE rn = 1              -- deduplicate by Row ID
  AND order_date IS NOT NULL
  AND ship_date IS NOT NULL
  AND ship_date >= order_date
ORDER BY row_id;

-- Clean-table constraints
ALTER TABLE analytics.clean_orders
    ADD PRIMARY KEY (row_id),
    ALTER COLUMN order_id SET NOT NULL,
    ALTER COLUMN order_date SET NOT NULL,
    ALTER COLUMN ship_date SET NOT NULL,
    ALTER COLUMN customer_id SET NOT NULL,
    ALTER COLUMN sales SET NOT NULL,
    ALTER COLUMN quantity SET NOT NULL,
    ALTER COLUMN discount SET NOT NULL,
    ALTER COLUMN profit SET NOT NULL,
    ADD CONSTRAINT chk_sales_non_negative CHECK (sales >= 0),
    ADD CONSTRAINT chk_quantity_positive CHECK (quantity > 0),
    ADD CONSTRAINT chk_discount_range CHECK (discount BETWEEN 0 AND 1),
    ADD CONSTRAINT chk_ship_after_order CHECK (ship_date >= order_date);

CREATE INDEX idx_clean_order_id ON analytics.clean_orders (order_id);
CREATE INDEX idx_clean_order_date ON analytics.clean_orders (order_date);

COMMIT;
