-- ============================================================================
-- 04_public_app_cost_controls.sql
-- Run BEFORE making the Streamlit app public (e.g. Streamlit Community Cloud),
-- as ACCOUNTADMIN. Every visitor's page view runs queries on WH_BI_QUERY, so
-- cap what an open URL can spend.
--
-- Note: WH_BI_QUERY is shared with Lightdash / other BI (see
-- 00_setup_database_warehouse.sql). This downsizes it for all of them, which
-- is fine at demo data volumes.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- 1. Smallest footprint: XSMALL, one cluster, suspend after 60s idle.
--    (Was MEDIUM, up to 4 clusters, 300s auto-suspend.)
-- ---------------------------------------------------------------------------
ALTER WAREHOUSE WH_BI_QUERY SET
  WAREHOUSE_SIZE = 'XSMALL'
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 1
  AUTO_SUSPEND = 60
  STATEMENT_TIMEOUT_IN_SECONDS = 60
  STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 60;

-- ---------------------------------------------------------------------------
-- 2. Hard monthly credit cap: notify at 50% / 80%, suspend at 100%.
--    XSMALL = 1 credit/hour, so 10 credits = ~10 warehouse-hours per month.
--    Raise CREDIT_QUOTA if the demo gets real traffic.
-- ---------------------------------------------------------------------------
CREATE RESOURCE MONITOR IF NOT EXISTS RM_BI_QUERY_PUBLIC_APP
  WITH
    CREDIT_QUOTA = 10
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 50 PERCENT DO NOTIFY
    ON 80 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND
    ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE WH_BI_QUERY SET RESOURCE_MONITOR = RM_BI_QUERY_PUBLIC_APP;

-- Check:
-- SHOW WAREHOUSES LIKE 'WH_BI_QUERY';
-- SHOW RESOURCE MONITORS LIKE 'RM_BI_QUERY_PUBLIC_APP';
