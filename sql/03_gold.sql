-- Gold layer: the dimensional model (star schemas + one event table).
-- Facts join dimensions on surrogate keys; the fact primary key is the grain.
-- A conformed dim_date is shared by every fact and the event table.
DROP SCHEMA IF EXISTS gold CASCADE;

CREATE SCHEMA gold;

CREATE TABLE gold.dim_date (
    date_key INT PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    year SMALLINT NOT NULL,
    quarter SMALLINT NOT NULL,
    month SMALLINT NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    day SMALLINT NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

CREATE TABLE gold.dim_chip (
    chip_id SERIAL PRIMARY KEY,
    chip_name VARCHAR(100) NOT NULL UNIQUE,
    vendor VARCHAR(100) NOT NULL,
    launch_date DATE,
    memory_gb INT,
    fp16_tflops NUMERIC(10, 2),
    tdp_watts INT,
    description TEXT
);

CREATE TABLE gold.fact_chip_year (
    chip_id INT REFERENCES gold.dim_chip (chip_id),
    date_key INT REFERENCES gold.dim_date (date_key),
    estimated_shipments_units BIGINT,
    estimated_asp_usd NUMERIC(12, 2),
    estimated_revenue_usd_m NUMERIC(12, 2),
    PRIMARY KEY (chip_id, date_key)
);

CREATE INDEX idx_fact_chip_year_date ON gold.fact_chip_year (date_key);

CREATE TABLE gold.dim_company (
    company_id SMALLSERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL UNIQUE,
    country_or_region CHAR(3) NOT NULL,
    ticker VARCHAR(10),
    segment VARCHAR(50) NOT NULL
);

CREATE TABLE gold.fact_financials_year (
    company_id SMALLINT REFERENCES gold.dim_company (company_id),
    date_key INT REFERENCES gold.dim_date (date_key),
    revenue_usd_bn NUMERIC(10, 2),
    operating_margin_pct NUMERIC(5, 2),
    operating_income_usd_bn NUMERIC(10, 2),
    rd_spend_usd_bn NUMERIC(10, 2),
    capex_usd_bn NUMERIC(10, 2),
    PRIMARY KEY (company_id, date_key)
);

CREATE INDEX idx_fact_financials_year_date ON gold.fact_financials_year (date_key);

CREATE TABLE gold.dim_product (
    product_id SMALLSERIAL PRIMARY KEY,
    product_name VARCHAR(50) NOT NULL UNIQUE,
    unit VARCHAR(30) NOT NULL
);

CREATE TABLE gold.fact_product_price_month (
    product_id SMALLINT REFERENCES gold.dim_product (product_id),
    date_key INT REFERENCES gold.dim_date (date_key),
    currency CHAR(3) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (product_id, date_key)
);

CREATE INDEX idx_fact_product_price_month_date ON gold.fact_product_price_month (
    date_key
);

CREATE TABLE gold.dim_fab (
    fab_id SMALLSERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    country_iso3 CHAR(3) NOT NULL,
    process_node_nm NUMERIC(5, 2) NOT NULL,
    fab_type VARCHAR(30) NOT NULL,
    fab_started_year SMALLINT,
    UNIQUE (
        company_name,
        country_iso3,
        process_node_nm,
        fab_type
    )
);

CREATE TABLE gold.fact_fab_capacity_year (
    fab_id SMALLINT REFERENCES gold.dim_fab (fab_id),
    date_key INT REFERENCES gold.dim_date (date_key),
    monthly_wafer_capacity NUMERIC(12, 2),
    PRIMARY KEY (fab_id, date_key)
);

CREATE INDEX idx_fact_fab_capacity_year_date ON gold.fact_fab_capacity_year (date_key);

CREATE TABLE gold.export_control_event (
    control_id VARCHAR(50) PRIMARY KEY,
    date_key INT REFERENCES gold.dim_date (date_key),
    imposing_country CHAR(3) NOT NULL,
    target VARCHAR(100) NOT NULL,
    policy_name VARCHAR(100) NOT NULL,
    severity_score SMALLINT CHECK (severity_score BETWEEN 1 AND 10),
    description TEXT,
    era VARCHAR(20) NOT NULL CHECK (era IN ('trump_1_0', 'biden', 'trump_2_0'))
);
