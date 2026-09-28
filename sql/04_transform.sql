-- bronze -> silver: cast, conform, derive.
-- silver -> gold: build dim_date, dedupe natural keys into dims, join back for surrogate keys.

-- ===== ai_chip_market: bronze -> silver =====
INSERT INTO silver.ai_chip_market (
    year, chip_name, vendor, launch_date, memory_gb, fp16_tflops, tdp_watts,
    estimated_shipments_units,
    estimated_asp_usd,
    estimated_revenue_usd_m,
    description
)
SELECT
    year::smallint,
    chip_name,
    vendor,
    launch_date::date,
    memory_gb::int,
    fp16_tflops::numeric,
    tdp_watts::int,
    estimated_shipments_units::bigint,
    estimated_asp_usd::numeric,
    estimated_revenue_usd_m::numeric,
    description
FROM bronze.ai_chip_market;

-- ===== chip_companies_financials: bronze -> silver =====
INSERT INTO silver.chip_companies_financials (
    year, company_name, ticker, country_iso3, segment,
    revenue_usd_bn,
    operating_margin_pct,
    operating_income_usd_bn,
    rd_spend_usd_bn,
    capex_usd_bn
)
SELECT
    year::smallint,
    company_name,
    ticker,
    country_iso3,
    CASE segment
        WHEN 'fabless_cpu_gpu' THEN 'fabless_gpu'
        ELSE segment
    END,
    revenue_usd_bn::numeric,
    operating_margin_pct::numeric,
    operating_income_usd_bn::numeric,
    rd_spend_usd_bn::numeric,
    capex_usd_bn::numeric
FROM bronze.chip_companies_financials;

-- ===== chip_prices: bronze -> silver =====
INSERT INTO silver.chip_prices (
    year_month, year, product, currency, unit, price
)
SELECT
    (year_month || '-01')::date,
    year::smallint,
    product,
    currency,
    unit,
    price::numeric
FROM bronze.chip_prices;

-- ===== fab_capacity: bronze -> silver =====
INSERT INTO silver.fab_capacity (
    year,
    company,
    country_iso3,
    process_node_nm,
    fab_type,
    monthly_wafer_capacity,
    fab_started_year
)
SELECT
    year::smallint,
    company,
    country_iso3,
    process_node_nm::numeric,
    fab_type,
    monthly_wafer_capacity::numeric,
    fab_started_year::smallint
FROM bronze.fab_capacity;

-- ===== export_controls: bronze -> silver (derive era, drop flags) =====
INSERT INTO silver.export_controls (
    control_id,
    event_date,
    imposing_country,
    target,
    policy_name,
    severity_score,
    description,
    era
)
SELECT
    control_id,
    date::date,
    imposing_country,
    target,
    policy_name,
    severity_score::smallint,
    description,
    CASE
        WHEN is_trump_1_0 = '1' THEN 'trump_1_0'
        WHEN is_biden = '1' THEN 'biden'
        WHEN is_trump_2_0 = '1' THEN 'trump_2_0'
    END
FROM bronze.export_controls;

-- ===== dim_date: conformed date spine (day grain, 2010-2026) =====
INSERT INTO gold.dim_date (
    date_key, date, year, quarter, month, month_name, day, is_weekend
)
SELECT
    to_char(d, 'YYYYMMDD')::int,
    d::date,
    extract(YEAR FROM d)::smallint,
    extract(QUARTER FROM d)::smallint,
    extract(MONTH FROM d)::smallint,
    to_char(d, 'FMMonth'),
    extract(DAY FROM d)::smallint,
    extract(ISODOW FROM d) IN (6, 7)
FROM generate_series('2010-01-01'::date, '2026-12-31'::date, '1 day') AS d;

-- ===== silver -> gold: ai_chip_market -> dim_chip, fact_chip_year =====
INSERT INTO gold.dim_chip (
    vendor,
    chip_name,
    launch_date,
    memory_gb,
    fp16_tflops,
    tdp_watts,
    description
)
SELECT DISTINCT
    vendor,
    chip_name,
    launch_date,
    memory_gb,
    fp16_tflops,
    tdp_watts,
    description
FROM silver.ai_chip_market;

INSERT INTO gold.fact_chip_year (
    chip_id,
    date_key,
    estimated_shipments_units,
    estimated_asp_usd,
    estimated_revenue_usd_m
)
SELECT
    c.chip_id,
    to_char(to_date(s.year::text, 'YYYY'), 'YYYYMMDD')::int,
    s.estimated_shipments_units,
    s.estimated_asp_usd,
    s.estimated_revenue_usd_m
FROM silver.ai_chip_market AS s
INNER JOIN gold.dim_chip AS c ON s.chip_name = c.chip_name;

-- ===== silver -> gold: chip_companies_financials -> dim_company, fact_financials_year =====
INSERT INTO gold.dim_company (company_name, country_or_region, ticker, segment)
SELECT DISTINCT
    company_name,
    country_iso3,
    ticker,
    segment
FROM silver.chip_companies_financials;

INSERT INTO gold.fact_financials_year (
    company_id, date_key, revenue_usd_bn, operating_margin_pct,
    operating_income_usd_bn, rd_spend_usd_bn, capex_usd_bn
)
SELECT
    c.company_id,
    to_char(to_date(s.year::text, 'YYYY'), 'YYYYMMDD')::int,
    s.revenue_usd_bn,
    s.operating_margin_pct,
    s.operating_income_usd_bn,
    s.rd_spend_usd_bn,
    s.capex_usd_bn
FROM silver.chip_companies_financials AS s
INNER JOIN gold.dim_company AS c ON s.company_name = c.company_name;

-- ===== silver -> gold: chip_prices -> dim_product, fact_product_price_month =====
INSERT INTO gold.dim_product (product_name, unit)
SELECT DISTINCT
    product,
    unit
FROM silver.chip_prices;

INSERT INTO gold.fact_product_price_month (
    product_id, date_key, currency, price
)
SELECT
    p.product_id,
    to_char(s.year_month, 'YYYYMMDD')::int,
    s.currency,
    s.price
FROM silver.chip_prices AS s
INNER JOIN gold.dim_product AS p ON s.product = p.product_name;

-- ===== silver -> gold: fab_capacity -> dim_fab, fact_fab_capacity_year =====
INSERT INTO gold.dim_fab (
    company_name, company_id, country_iso3, process_node_nm, fab_type, fab_started_year
)
SELECT DISTINCT
    s.company,
    c.company_id,
    s.country_iso3,
    s.process_node_nm,
    s.fab_type,
    s.fab_started_year
FROM silver.fab_capacity AS s
LEFT JOIN gold.dim_company AS c ON s.company = c.company_name;

INSERT INTO gold.fact_fab_capacity_year (
    fab_id, date_key, monthly_wafer_capacity
)
SELECT
    f.fab_id,
    to_char(to_date(s.year::text, 'YYYY'), 'YYYYMMDD')::int,
    s.monthly_wafer_capacity
FROM silver.fab_capacity AS s
INNER JOIN gold.dim_fab AS f
    ON
        s.company = f.company_name
        AND s.country_iso3 = f.country_iso3
        AND s.process_node_nm = f.process_node_nm
        AND s.fab_type = f.fab_type;

-- ===== silver -> gold: export_controls -> export_control_event =====
INSERT INTO gold.export_control_event (
    control_id,
    date_key,
    imposing_country,
    target,
    policy_name,
    severity_score,
    description,
    era
)
SELECT
    control_id,
    to_char(event_date, 'YYYYMMDD')::int,
    imposing_country,
    target,
    policy_name,
    severity_score,
    description,
    era
FROM silver.export_controls;
