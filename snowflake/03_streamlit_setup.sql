-- ============================================================================
-- 03_streamlit_setup.sql
-- Read-only access for the Streamlit app (streamlit_app/). Run after 00-02 and
-- after dbt has built the marts, as ACCOUNTADMIN on a trial account (or
-- SYSADMIN + SECURITYADMIN in prod).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Grants: extend BI_READER to the Student and Finance marts
--    (00_setup_database_warehouse.sql only covers MARTS_CORE / MARTS_HR).
-- ---------------------------------------------------------------------------
USE ROLE SYSADMIN;

CREATE SCHEMA IF NOT EXISTS HR_ANALYTICS.MARTS_STUDENT
  COMMENT = 'Student facts/dims: dim_student, dim_program, dim_academic_period, fact_enrollment.';

CREATE SCHEMA IF NOT EXISTS HR_ANALYTICS.MARTS_FINANCE
  COMMENT = 'Finance facts/dims: dim_gl_account, dim_cost_center, fact_gl_transactions.';

GRANT USAGE ON SCHEMA HR_ANALYTICS.MARTS_STUDENT TO ROLE BI_READER;
GRANT USAGE ON SCHEMA HR_ANALYTICS.MARTS_FINANCE TO ROLE BI_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.MARTS_STUDENT TO ROLE BI_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.MARTS_FINANCE TO ROLE BI_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.MARTS_STUDENT TO ROLE BI_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.MARTS_FINANCE TO ROLE BI_READER;

-- dbt needs to write to the two new schemas when building with the prod target.
GRANT ALL ON SCHEMA HR_ANALYTICS.MARTS_STUDENT TO ROLE DBT_TRANSFORMER;
GRANT ALL ON SCHEMA HR_ANALYTICS.MARTS_FINANCE TO ROLE DBT_TRANSFORMER;

-- ---------------------------------------------------------------------------
-- 1b. OPTIONAL: dev-target schemas.
--     If the marts were only ever built with the dev target, they live in
--     <target_schema>_MARTS_* (e.g. DEV_MAYURESH_MARTS_CORE), owned by
--     DBT_TRANSFORMER. Grant BI_READER on those instead, and set
--     marts_schema_prefix = "DEV_MAYURESH" in .streamlit/secrets.toml.
-- ---------------------------------------------------------------------------
-- USE ROLE DBT_TRANSFORMER;
-- GRANT USAGE ON SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_CORE TO ROLE BI_READER;
-- GRANT USAGE ON SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_HR TO ROLE BI_READER;
-- GRANT USAGE ON SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_STUDENT TO ROLE BI_READER;
-- GRANT USAGE ON SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_FINANCE TO ROLE BI_READER;
-- GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_CORE TO ROLE BI_READER;
-- GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_HR TO ROLE BI_READER;
-- GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_STUDENT TO ROLE BI_READER;
-- GRANT SELECT ON ALL TABLES IN SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_FINANCE TO ROLE BI_READER;
-- GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_CORE TO ROLE BI_READER;
-- GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_HR TO ROLE BI_READER;
-- GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_STUDENT TO ROLE BI_READER;
-- GRANT SELECT ON FUTURE TABLES IN SCHEMA HR_ANALYTICS.DEV_MAYURESH_MARTS_FINANCE TO ROLE BI_READER;

-- ---------------------------------------------------------------------------
-- 2. Service user for the app (key-pair auth, no password).
--
--    Generate the key pair locally (never commit or paste the private key):
--      mkdir -p ~/.snowflake/keys && cd ~/.snowflake/keys
--      openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out streamlit_app_rsa_key.p8 -nocrypt
--      openssl rsa -in streamlit_app_rsa_key.p8 -pubout -out streamlit_app_rsa_key.pub
--      chmod 600 streamlit_app_rsa_key.p8
--
--    Paste the contents of streamlit_app_rsa_key.pub below, WITHOUT the
--    -----BEGIN/END PUBLIC KEY----- lines and joined onto one line:
--      grep -v "PUBLIC KEY" streamlit_app_rsa_key.pub | tr -d '\n'
-- ---------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

CREATE USER IF NOT EXISTS STREAMLIT_APP_USER
  TYPE = SERVICE
  DEFAULT_ROLE = BI_READER
  DEFAULT_WAREHOUSE = WH_BI_QUERY
  DEFAULT_NAMESPACE = HR_ANALYTICS
  COMMENT = 'Streamlit app (streamlit_app/). Read-only via BI_READER.';

ALTER USER STREAMLIT_APP_USER SET RSA_PUBLIC_KEY = '<paste_public_key_here>';

GRANT ROLE BI_READER TO USER STREAMLIT_APP_USER;

-- Sanity check: RSA_PUBLIC_KEY_FP should be populated.
-- DESC USER STREAMLIT_APP_USER;

-- ---------------------------------------------------------------------------
-- 3. OPTIONAL: deploy to Streamlit in Snowflake (SiS) later.
--    The app detects the SiS session automatically (lib/connection.py).
-- ---------------------------------------------------------------------------
-- USE ROLE SYSADMIN;
-- CREATE SCHEMA IF NOT EXISTS HR_ANALYTICS.APPS;
-- CREATE STAGE IF NOT EXISTS HR_ANALYTICS.APPS.STREAMLIT_STAGE
--   DIRECTORY = (ENABLE = TRUE);
--
-- From the repo root, upload the app with SnowSQL / Snowflake CLI:
--   PUT file://streamlit_app/app.py              @HR_ANALYTICS.APPS.STREAMLIT_STAGE/ AUTO_COMPRESS = FALSE OVERWRITE = TRUE;
--   PUT file://streamlit_app/environment.yml     @HR_ANALYTICS.APPS.STREAMLIT_STAGE/ AUTO_COMPRESS = FALSE OVERWRITE = TRUE;
--   PUT file://streamlit_app/lib/*.py            @HR_ANALYTICS.APPS.STREAMLIT_STAGE/lib/ AUTO_COMPRESS = FALSE OVERWRITE = TRUE;
--   PUT file://streamlit_app/pages/*.py          @HR_ANALYTICS.APPS.STREAMLIT_STAGE/pages/ AUTO_COMPRESS = FALSE OVERWRITE = TRUE;
--
-- CREATE STREAMLIT IF NOT EXISTS HR_ANALYTICS.APPS.WORKDAY_HR_ANALYTICS
--   ROOT_LOCATION = '@HR_ANALYTICS.APPS.STREAMLIT_STAGE'
--   MAIN_FILE = 'app.py'
--   QUERY_WAREHOUSE = WH_BI_QUERY
--   TITLE = 'Workday HR Analytics';
-- GRANT USAGE ON SCHEMA HR_ANALYTICS.APPS TO ROLE BI_READER;
-- GRANT USAGE ON STREAMLIT HR_ANALYTICS.APPS.WORKDAY_HR_ANALYTICS TO ROLE BI_READER;
