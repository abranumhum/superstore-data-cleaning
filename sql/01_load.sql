-- 01_load.sql
-- Create the raw table that matches the dirty CSV column names exactly.
BEGIN;

DROP TABLE IF EXISTS raw.orders;
DROP SCHEMA IF EXISTS analytics CASCADE;

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE raw.orders (
    "Row ID"              bigint,
    "Order ID"            text,
    "Order Date"          text,
    "Ship Date"           text,
    "Ship Mode"           text,
    "Customer ID"         text,
    "Customer Name"       text,
    "Segment"             text,
    "Country/Region"      text,
    "City"                text,
    "State/Province"      text,
    "Postal Code"         text,
    "Region"              text,
    "Product ID"          text,
    "Category"            text,
    "Sub-Category"        text,
    "Product Name"        text,
    "Sales"               text,
    "Quantity"            text,
    "Discount"            text,
    "Profit"              text
);

COMMIT;
