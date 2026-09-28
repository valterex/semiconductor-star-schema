-- Sample analytical queries against the gold (star-schema) layer.
SET
search_path = gold;

-- Total estimated chip revenue by vendor
SELECT
    c.vendor,
    SUM(f.estimated_revenue_usd_m) AS total_revenue_usd_m
FROM
    fact_chip_year AS f
INNER JOIN dim_chip AS c ON f.chip_id = c.chip_id
GROUP BY
    c.vendor
ORDER BY
    total_revenue_usd_m DESC;

-- All fabs and their 2024 capacity; NULL where a fab has no 2024 record
WITH
c AS (
    SELECT
        fc.fab_id,
        fc.monthly_wafer_capacity
    FROM
        fact_fab_capacity_year AS fc
    INNER JOIN dim_date AS d ON fc.date_key = d.date_key
    WHERE
        d.year = 2024
)

SELECT
    f.company_name,
    f.country_iso3,
    f.process_node_nm,
    f.fab_type,
    c.monthly_wafer_capacity AS capacity_2024
FROM
    dim_fab AS f
LEFT JOIN c ON f.fab_id = c.fab_id
ORDER BY
    capacity_2024 DESC NULLS LAST;

-- Segments with more than 3 companies
SELECT
    segment,
    COUNT(*) AS companies
FROM
    dim_company
GROUP BY
    segment
HAVING
    COUNT(*) > 3
ORDER BY
    companies DESC;

-- Revenue with the previous year's revenue
SELECT
    c.company_name,
    d.year,
    f.revenue_usd_bn,
    LAG(f.revenue_usd_bn) OVER (
        PARTITION BY
            f.company_id
        ORDER BY
            f.date_key
    ) AS prev_year_revenue
FROM
    fact_financials_year AS f
INNER JOIN dim_company AS c ON f.company_id = c.company_id
INNER JOIN dim_date AS d ON f.date_key = d.date_key
ORDER BY
    c.company_name,
    f.date_key;

-- Top 5 companies by total revenue (CTE + aggregation)
WITH
company_totals AS (
    SELECT
        company_id,
        SUM(revenue_usd_bn) AS total_revenue
    FROM
        fact_financials_year
    GROUP BY
        company_id
)

SELECT
    c.company_name,
    t.total_revenue
FROM
    company_totals AS t
INNER JOIN dim_company AS c ON t.company_id = c.company_id
ORDER BY
    t.total_revenue DESC
LIMIT
    5;
