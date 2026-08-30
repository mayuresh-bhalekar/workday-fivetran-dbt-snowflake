-- ============================================================================
-- 00_setup_database_warehouse.sql
-- Run as a role with CREATE DATABASE / CREATE WAREHOUSE / CREATE ROLE privileges
-- (e.g. ACCOUNTADMIN on a trial account, or SYSADMIN + SECURITYADMIN in prod)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Roles (least-privilege separation between ingestion, transformation, BI)
-- ---------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS FIVETRAN_LOADER;   -- Fivetran service account role: write RAW only
CREATE ROLE IF NOT EXISTS DBT_TRANSFORMER;   -- dbt service account role: read RAW, write STAGING/MARTS
CREATE ROLE IF NOT EXISTS BI_READER;         -- BI tool / analyst role: read MARTS only

USE ROLE SYSADMIN;

-- ---------------------------------------------------------------------------
-- Warehouses (workload isolation for clean cost attribution + no contention)
-- ---------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS WH_FIVETRAN_LOAD
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Fivetran RAW ingestion. Small + fast-suspend: short bursty loads.';

CREATE WAREHOUSE IF NOT EXISTS WH_DBT_TRANSFORM
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 3
  SCALING_POLICY = 'STANDARD'
  COMMENT = 'Scheduled dbt build/test runs. Auto-scale for parallel model execution.';

CREATE WAREHOUSE IF NOT EXISTS WH_BI_QUERY
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 4
  SCALING_POLICY = 'ECONOMY'
  COMMENT = 'BI tool / analyst ad-hoc queries. Longer suspend to preserve dashboard cache hits.';

-- ---------------------------------------------------------------------------
-- Database + schemas
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS HR_ANALYTICS
  COMMENT = 'Workday HCM/Payroll/Time/Benefits analytics platform';

USE DATABASE HR_ANALYTICS;

CREATE SCHEMA IF NOT EXISTS RAW
  COMMENT = 'Fivetran-owned. 1:1 replica of Workday RaaS reports. Append-only, never hand-edited.';

CREATE SCHEMA IF NOT EXISTS STAGING
  COMMENT = 'dbt staging layer: stg_ views, typed/renamed, no business logic.';

CREATE SCHEMA IF NOT EXISTS INTERMEDIATE
  COMMENT = 'dbt intermediate layer: int_ models, cross-source joins, not BI-facing.';

CREATE SCHEMA IF NOT EXISTS MARTS_CORE
  COMMENT = 'Conformed dimensions: dim_employee, dim_department, dim_position, dim_location, dim_date.';

CREATE SCHEMA IF NOT EXISTS MARTS_HR
  COMMENT = 'Atomic-grain facts: fact_hours_worked, fact_pay, fact_benefits_enrollment.';

CREATE SCHEMA IF NOT EXISTS SNAPSHOTS
  COMMENT = 'dbt snapshot tables holding SCD2 raw history (e.g. snap_workers).';

-- ---------------------------------------------------------------------------
-- Grants (least privilege)
-- ---------------------------------------------------------------------------
GRANT USAGE ON DATABASE HR_ANALYTICS TO ROLE FIVETRAN_LOADER;
GRANT USAGE, CREATE TABLE ON SCHEMA HR_ANALYTICS.RAW TO ROLE FIVETRAN_LOADER;
GRANT USAGE ON WAREHOUSE WH_FIVETRAN_LOAD TO ROLE FIVETRAN_LOADER;

GRANT USAGE ON DATABASE HR_ANALYTICS TO ROLE DBT_TRANSFORMER;
GRANT USAGE ON SCHEMA HR_ANALYTICS.RAW TO ROLE DBT_TRANSFORMER;
GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.RAW TO ROLE DBT_TRANSFORMER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.RAW TO ROLE DBT_TRANSFORMER;
GRANT ALL ON SCHEMA HR_ANALYTICS.STAGING TO ROLE DBT_TRANSFORMER;
GRANT ALL ON SCHEMA HR_ANALYTICS.INTERMEDIATE TO ROLE DBT_TRANSFORMER;
GRANT ALL ON SCHEMA HR_ANALYTICS.MARTS_CORE TO ROLE DBT_TRANSFORMER;
GRANT ALL ON SCHEMA HR_ANALYTICS.MARTS_HR TO ROLE DBT_TRANSFORMER;
GRANT ALL ON SCHEMA HR_ANALYTICS.SNAPSHOTS TO ROLE DBT_TRANSFORMER;
GRANT USAGE ON WAREHOUSE WH_DBT_TRANSFORM TO ROLE DBT_TRANSFORMER;

GRANT USAGE ON DATABASE HR_ANALYTICS TO ROLE BI_READER;
GRANT USAGE ON SCHEMA HR_ANALYTICS.MARTS_CORE TO ROLE BI_READER;
GRANT USAGE ON SCHEMA HR_ANALYTICS.MARTS_HR TO ROLE BI_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.MARTS_CORE TO ROLE BI_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.MARTS_HR TO ROLE BI_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.MARTS_CORE TO ROLE BI_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.MARTS_HR TO ROLE BI_READER;
GRANT USAGE ON WAREHOUSE WH_BI_QUERY TO ROLE BI_READER;

-- Attach roles to your actual users/service accounts, e.g.:
-- GRANT ROLE DBT_TRANSFORMER TO USER DBT_SERVICE_ACCOUNT;
