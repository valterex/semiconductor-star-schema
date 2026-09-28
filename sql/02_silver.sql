-- Silver layer: typed, cleaned, conformed. Cast TEXT to real types,
-- normalize vocabulary, derive columns, drop derivable flags.
DROP SCHEMA IF EXISTS silver CASCADE;

CREATE SCHEMA silver;

CREATE TABLE silver.ai_chip_market (
    year SMALLINT,
    chip_name VARCHAR(100),
    vendor VARCHAR(100),
    launch_date DATE,
    memory_gb INT,
    fp16_tflops NUMERIC(10, 2),
    tdp_watts INT,
    estimated_shipments_units BIGINT,
    estimated_asp_usd NUMERIC(12, 2),
    estimated_revenue_usd_m NUMERIC(12, 2),
    description TEXT
);

CREATE TABLE silver.chip_companies_financials (
    year SMALLINT,
    company_name VARCHAR(100),
    ticker VARCHAR(10),
    country_iso3 CHAR(3),
    segment VARCHAR(50),
    revenue_usd_bn NUMERIC(10, 2),
    operating_margin_pct NUMERIC(5, 2),
    operating_income_usd_bn NUMERIC(10, 2),
    rd_spend_usd_bn NUMERIC(10, 2),
    capex_usd_bn NUMERIC(10, 2)
);

CREATE TABLE silver.chip_prices (
    year_month DATE,
    year SMALLINT,
    product VARCHAR(50),
    currency CHAR(3),
    unit VARCHAR(30),
    price NUMERIC(10, 2)
);

CREATE TABLE silver.fab_capacity (
    year SMALLINT,
    company VARCHAR(100),
    country_iso3 CHAR(3),
    process_node_nm NUMERIC(5, 2),
    fab_type VARCHAR(30),
    monthly_wafer_capacity NUMERIC(12, 2),
    fab_started_year SMALLINT
);

CREATE TABLE silver.export_controls (
    control_id VARCHAR(50),
    event_date DATE,
    imposing_country CHAR(3),
    target VARCHAR(100),
    policy_name VARCHAR(100),
    severity_score SMALLINT,
    description TEXT,
    era VARCHAR(20)
);
