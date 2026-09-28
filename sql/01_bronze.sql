-- Bronze layer: raw CSV mirrors, one table per source, all TEXT.
-- Loaded verbatim via COPY so a bad value can never break the ingest.
DROP SCHEMA IF EXISTS bronze CASCADE;

CREATE SCHEMA bronze;

CREATE TABLE bronze.ai_chip_market (
    year TEXT,
    chip_name TEXT,
    vendor TEXT,
    launch_date TEXT,
    memory_gb TEXT,
    fp16_tflops TEXT,
    tdp_watts TEXT,
    estimated_shipments_units TEXT,
    estimated_asp_usd TEXT,
    estimated_revenue_usd_m TEXT,
    description TEXT
);

CREATE TABLE bronze.chip_companies_financials (
    year TEXT,
    company_name TEXT,
    ticker TEXT,
    country_iso3 TEXT,
    segment TEXT,
    revenue_usd_bn TEXT,
    operating_margin_pct TEXT,
    operating_income_usd_bn TEXT,
    rd_spend_usd_bn TEXT,
    capex_usd_bn TEXT
);

CREATE TABLE bronze.chip_prices (
    year_month TEXT,
    year TEXT,
    product TEXT,
    currency TEXT,
    unit TEXT,
    price TEXT
);

CREATE TABLE bronze.fab_capacity (
    year TEXT,
    company TEXT,
    country_iso3 TEXT,
    process_node_nm TEXT,
    fab_type TEXT,
    monthly_wafer_capacity TEXT,
    fab_started_year TEXT
);

CREATE TABLE bronze.export_controls (
    control_id TEXT,
    date TEXT,
    year TEXT,
    month TEXT,
    imposing_country TEXT,
    target TEXT,
    policy_name TEXT,
    severity_score TEXT,
    description TEXT,
    is_us_action TEXT,
    is_china_action TEXT,
    is_netherlands_action TEXT,
    is_trump_1_0 TEXT,
    is_biden TEXT,
    is_trump_2_0 TEXT
);
