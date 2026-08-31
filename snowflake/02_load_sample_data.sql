-- ============================================================================
-- 02_load_sample_data.sql
-- Simulates a Fivetran initial sync by bulk-loading the CSVs in sample_data/
-- into RAW via Snowflake's internal stage + COPY INTO (PUT is a SnowSQL/CLI
-- command, not plain SQL — see the snowsql block below).
-- ============================================================================
USE DATABASE HR_ANALYTICS;
USE SCHEMA RAW;
USE WAREHOUSE WH_FIVETRAN_LOAD;

CREATE FILE FORMAT IF NOT EXISTS RAW.CSV_STANDARD
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    DATE_FORMAT = 'YYYY-MM-DD'
    TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS';

CREATE STAGE IF NOT EXISTS RAW.SAMPLE_DATA_STAGE
    FILE_FORMAT = RAW.CSV_STANDARD
    COMMENT = 'Internal stage for loading sample_data/*.csv (demo stand-in for Fivetran).';

-- ---------------------------------------------------------------------------
-- Run these PUT commands from SnowSQL (CLI) from the repo root — PUT is a
-- client-side command and cannot run from the classic web worksheet:
--
--   snowsql -a <account> -u <user>
--   USE DATABASE HR_ANALYTICS; USE SCHEMA RAW;
--   PUT file://sample_data/workday_departments.csv          @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_locations.csv            @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_positions.csv             @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_workers.csv                @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_time_entries.csv             @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_pay_results.csv                @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_benefits_enrollment.csv          @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_academic_periods.csv              @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_programs.csv                       @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_students.csv                        @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_course_registrations.csv             @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_ledger_accounts.csv                   @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_cost_centers.csv                       @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--   PUT file://sample_data/workday_gl_transactions.csv                     @RAW.SAMPLE_DATA_STAGE AUTO_COMPRESS=TRUE;
--
-- Alternatively, upload via Snowsight: Data > Databases > HR_ANALYTICS > RAW >
-- Stages > SAMPLE_DATA_STAGE > "+ Files".
-- ---------------------------------------------------------------------------

COPY INTO RAW.WORKDAY_DEPARTMENTS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_departments.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_LOCATIONS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_locations.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_POSITIONS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_positions.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_WORKERS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_workers.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_TIME_ENTRIES
  FROM @RAW.SAMPLE_DATA_STAGE/workday_time_entries.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_PAY_RESULTS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_pay_results.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_BENEFITS_ENROLLMENT
  FROM @RAW.SAMPLE_DATA_STAGE/workday_benefits_enrollment.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_ACADEMIC_PERIODS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_academic_periods.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_PROGRAMS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_programs.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_STUDENTS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_students.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_COURSE_REGISTRATIONS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_course_registrations.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_LEDGER_ACCOUNTS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_ledger_accounts.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_COST_CENTERS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_cost_centers.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.WORKDAY_GL_TRANSACTIONS
  FROM @RAW.SAMPLE_DATA_STAGE/workday_gl_transactions.csv.gz
  FILE_FORMAT = (FORMAT_NAME = RAW.CSV_STANDARD)
  ON_ERROR = 'ABORT_STATEMENT';

-- Sanity check row counts land as expected:
SELECT 'WORKDAY_DEPARTMENTS' AS table_name, COUNT(*) FROM RAW.WORKDAY_DEPARTMENTS
UNION ALL SELECT 'WORKDAY_LOCATIONS', COUNT(*) FROM RAW.WORKDAY_LOCATIONS
UNION ALL SELECT 'WORKDAY_POSITIONS', COUNT(*) FROM RAW.WORKDAY_POSITIONS
UNION ALL SELECT 'WORKDAY_WORKERS', COUNT(*) FROM RAW.WORKDAY_WORKERS
UNION ALL SELECT 'WORKDAY_TIME_ENTRIES', COUNT(*) FROM RAW.WORKDAY_TIME_ENTRIES
UNION ALL SELECT 'WORKDAY_PAY_RESULTS', COUNT(*) FROM RAW.WORKDAY_PAY_RESULTS
UNION ALL SELECT 'WORKDAY_BENEFITS_ENROLLMENT', COUNT(*) FROM RAW.WORKDAY_BENEFITS_ENROLLMENT
UNION ALL SELECT 'WORKDAY_ACADEMIC_PERIODS', COUNT(*) FROM RAW.WORKDAY_ACADEMIC_PERIODS
UNION ALL SELECT 'WORKDAY_PROGRAMS', COUNT(*) FROM RAW.WORKDAY_PROGRAMS
UNION ALL SELECT 'WORKDAY_STUDENTS', COUNT(*) FROM RAW.WORKDAY_STUDENTS
UNION ALL SELECT 'WORKDAY_COURSE_REGISTRATIONS', COUNT(*) FROM RAW.WORKDAY_COURSE_REGISTRATIONS
UNION ALL SELECT 'WORKDAY_LEDGER_ACCOUNTS', COUNT(*) FROM RAW.WORKDAY_LEDGER_ACCOUNTS
UNION ALL SELECT 'WORKDAY_COST_CENTERS', COUNT(*) FROM RAW.WORKDAY_COST_CENTERS
UNION ALL SELECT 'WORKDAY_GL_TRANSACTIONS', COUNT(*) FROM RAW.WORKDAY_GL_TRANSACTIONS;

-- ---------------------------------------------------------------------------
-- To simulate the SCD2 walkthrough (see README "Simulate SCD2"): truncate +
-- reload WORKDAY_WORKERS from workday_workers_v2_simulated_change.csv, then
-- re-run `dbt snapshot` and query SNAPSHOTS.SNAP_WORKERS to see both row
-- versions with dbt_valid_from / dbt_valid_to populated.
-- ---------------------------------------------------------------------------
