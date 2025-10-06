
-- RS_Electricals Analysis SQL Queries
-- NOTE: Replace column/table names with the actual names from Sheet1 if different.
-- Example schema creation (adjust types as needed)

/* 1. Create date dimension (example) */
-- For PostgreSQL: generate_series('2020-01-01'::date, '2025-12-31'::date, '1 day')

/* 2. Create staging table (assuming you loaded Sheet1 into staging_sheet1) */
CREATE TABLE staging_sheet1 (
  order_id TEXT,
  order_date DATE,
  customer_id TEXT,
  product_id TEXT,
  product_name TEXT,
  category TEXT,
  region TEXT,
  channel TEXT,
  quantity INTEGER,
  unit_price NUMERIC,
  revenue NUMERIC,
  profit NUMERIC
);

-- Create dim_product from staging
CREATE TABLE dim_product AS
SELECT DISTINCT product_id, product_name, category FROM staging_sheet1;

-- Create fact_sales from staging
CREATE TABLE fact_sales AS
SELECT
  order_id,
  order_date::date,
  customer_id,
  product_id,
  quantity::int,
  unit_price::numeric,
  COALESCE(revenue, quantity * unit_price) AS revenue,
  COALESCE(profit, 0) AS profit,
  channel,
  region
FROM staging_sheet1;

-- Basic KPIs
SELECT SUM(revenue) AS total_sales FROM fact_sales;
SELECT COUNT(DISTINCT order_id) AS total_orders FROM fact_sales;
SELECT SUM(profit) AS total_profit FROM fact_sales;
SELECT SUM(profit) / NULLIF(SUM(revenue),0) AS profit_margin FROM fact_sales;

-- Monthly revenue trend
SELECT TO_CHAR(DATE_TRUNC('month', order_date), 'YYYY-MM') AS year_month,
       SUM(revenue) AS revenue
FROM fact_sales
GROUP BY 1 ORDER BY 1;

-- Top 10 products by revenue
SELECT product_id, product_name, SUM(revenue) AS total_revenue, SUM(quantity) AS total_qty
FROM fact_sales
GROUP BY product_id, product_name
ORDER BY total_revenue DESC
LIMIT 10;

-- Sales by category, region, channel
SELECT category, SUM(revenue) AS revenue, SUM(profit) AS profit FROM fact_sales GROUP BY category ORDER BY revenue DESC;
SELECT region, SUM(revenue) AS revenue FROM fact_sales GROUP BY region ORDER BY revenue DESC;
SELECT channel, SUM(revenue) AS revenue FROM fact_sales GROUP BY channel ORDER BY revenue DESC;

-- Average order value (AOV)
SELECT AVG(order_revenue) AS aov FROM (
  SELECT order_id, SUM(revenue) AS order_revenue FROM fact_sales GROUP BY order_id
) t;

-- Month-over-Month growth
WITH monthly AS (
  SELECT DATE_TRUNC('month', order_date) AS month_start, SUM(revenue) AS revenue
  FROM fact_sales GROUP BY 1
)
SELECT month_start, revenue, LAG(revenue) OVER (ORDER BY month_start) AS prev_revenue,
       CASE WHEN LAG(revenue) OVER (ORDER BY month_start)=0 THEN NULL
            ELSE (revenue - LAG(revenue) OVER (ORDER BY month_start)) / LAG(revenue) OVER (ORDER BY month_start)
       END AS mom_growth
FROM monthly ORDER BY month_start;

-- Repeat purchase rate
SELECT COUNT(*) FILTER (WHERE orders > 1) * 1.0 / COUNT(*) AS repeat_rate FROM (
 SELECT customer_id, COUNT(DISTINCT order_id) AS orders FROM fact_sales GROUP BY customer_id
) s;

-- Data quality checks
SELECT COUNT(*) FILTER (WHERE order_date IS NULL) AS missing_order_date FROM staging_sheet1;
SELECT COUNT(*) FILTER (WHERE revenue IS NULL) AS missing_revenue FROM staging_sheet1;
SELECT MIN(order_date) AS min_date, MAX(order_date) AS max_date FROM staging_sheet1;

-- Views for Power BI (example)
CREATE VIEW vw_kpi_totals AS
SELECT
  SUM(revenue) AS total_sales,
  COUNT(DISTINCT order_id) AS total_orders,
  SUM(profit) AS total_profit,
  SUM(profit) / NULLIF(SUM(revenue),0) AS profit_margin
FROM fact_sales;

CREATE VIEW vw_monthly_agg AS
SELECT DATE_TRUNC('month', order_date) AS month_start,
       TO_CHAR(DATE_TRUNC('month', order_date), 'YYYY-MM') AS year_month,
       SUM(revenue) AS revenue,
       SUM(profit) AS profit,
       COUNT(DISTINCT order_id) AS orders
FROM fact_sales
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month_start;
