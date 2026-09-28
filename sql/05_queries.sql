-- Sample analytical queries against the gold (star-schema) layer.
SET
search_path = gold;

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

WITH
fab_capacity_2024 AS (
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
LEFT JOIN fab_capacity_2024 AS c ON f.fab_id = c.fab_id
ORDER BY
    capacity_2024 DESC NULLS LAST;

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

-- Currency is kept separate: averaging prices across currencies would be wrong.
SELECT
    f.currency,
    d.year,
    d.month_name,
    AVG(f.price) AS avg_price
FROM
    fact_product_price_month AS f
INNER JOIN dim_date AS d ON f.date_key = d.date_key
GROUP BY
    f.currency,
    d.year,
    d.month,
    d.month_name
ORDER BY
    f.currency,
    d.year,
    d.month;

SELECT
    era,
    imposing_country,
    COUNT(*) AS actions,
    AVG(severity_score) AS avg_severity
FROM
    export_control_event
GROUP BY
    era,
    imposing_country
ORDER BY
    era ASC,
    actions DESC;

-- Two facts are joined through the conformed dim_date (year) and the conformed
-- dim_company (via dim_fab.company_id). Fabs with no matching company drop out.
WITH
revenue AS (
    SELECT
        d.year,
        f.company_id,
        SUM(f.revenue_usd_bn) AS revenue_usd_bn
    FROM
        fact_financials_year AS f
    INNER JOIN dim_date AS d ON f.date_key = d.date_key
    GROUP BY
        d.year,
        f.company_id
),

capacity AS (
    SELECT
        d.year,
        fb.company_id,
        SUM(fc.monthly_wafer_capacity) AS total_capacity
    FROM
        fact_fab_capacity_year AS fc
    INNER JOIN dim_fab AS fb ON fc.fab_id = fb.fab_id
    INNER JOIN dim_date AS d ON fc.date_key = d.date_key
    WHERE
        fb.company_id IS NOT NULL
    GROUP BY
        d.year,
        fb.company_id
)

SELECT
    r.year,
    c.company_name,
    r.revenue_usd_bn,
    ca.total_capacity
FROM
    revenue AS r
INNER JOIN capacity AS ca
    ON
        r.company_id = ca.company_id
        AND r.year = ca.year
INNER JOIN dim_company AS c ON r.company_id = c.company_id
ORDER BY
    r.year ASC,
    r.revenue_usd_bn DESC;
