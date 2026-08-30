-- ============================================================================
-- 01_raw_schema_tables.sql
-- RAW tables shaped exactly as Fivetran's Workday connector would land them:
-- source columns as-is (typed) + Fivetran's standard sync metadata columns.
-- In a live pipeline Fivetran auto-creates/evolves these tables; this DDL
-- exists so the demo is runnable without a live Fivetran connection.
-- ============================================================================
USE DATABASE HR_ANALYTICS;
USE SCHEMA RAW;

CREATE TABLE IF NOT EXISTS WORKDAY_DEPARTMENTS (
    DEPARTMENT_ID     VARCHAR(20)   NOT NULL,
    DEPARTMENT_NAME   VARCHAR(200),
    COST_CENTER       VARCHAR(20),
    DIVISION          VARCHAR(100),
    _FIVETRAN_SYNCED  TIMESTAMP_NTZ,
    _FIVETRAN_DELETED BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_LOCATIONS (
    LOCATION_ID       VARCHAR(20)   NOT NULL,
    LOCATION_NAME     VARCHAR(200),
    COUNTRY           VARCHAR(10),
    TIME_ZONE         VARCHAR(50),
    _FIVETRAN_SYNCED  TIMESTAMP_NTZ,
    _FIVETRAN_DELETED BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_POSITIONS (
    POSITION_ID        VARCHAR(20)  NOT NULL,
    JOB_TITLE           VARCHAR(200),
    JOB_FAMILY           VARCHAR(100),
    MANAGEMENT_LEVEL      VARCHAR(50),
    FTE                    NUMBER(3,2),
    _FIVETRAN_SYNCED       TIMESTAMP_NTZ,
    _FIVETRAN_DELETED      BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_WORKERS (
    EMPLOYEE_ID          VARCHAR(20)  NOT NULL,
    FIRST_NAME            VARCHAR(100),
    LAST_NAME              VARCHAR(100),
    HIRE_DATE               DATE,
    TERMINATION_DATE         DATE,
    WORKER_STATUS             VARCHAR(20),
    POSITION_ID                VARCHAR(20),
    DEPARTMENT_ID                VARCHAR(20),
    MANAGER_EMPLOYEE_ID            VARCHAR(20),
    LOCATION_ID                     VARCHAR(20),
    COMPENSATION_BAND                VARCHAR(10),
    LAST_MODIFIED                     TIMESTAMP_NTZ,
    _FIVETRAN_SYNCED                   TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                   BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_TIME_ENTRIES (
    TIME_ENTRY_ID      VARCHAR(20)  NOT NULL,
    EMPLOYEE_ID          VARCHAR(20),
    ENTRY_DATE             DATE,
    HOURS_WORKED             NUMBER(5,2),
    OVERTIME_HOURS             NUMBER(5,2),
    TIME_TYPE                    VARCHAR(30),
    _FIVETRAN_SYNCED               TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_PAY_RESULTS (
    PAY_RESULT_ID        VARCHAR(20)  NOT NULL,
    EMPLOYEE_ID             VARCHAR(20),
    PAY_PERIOD_END_DATE      DATE,
    PAY_GROUP_ID                VARCHAR(30),
    CODE                           VARCHAR(30),
    CODE_TYPE                        VARCHAR(20),
    AMOUNT                             NUMBER(12,2),
    _FIVETRAN_SYNCED                     TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                      BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_BENEFITS_ENROLLMENT (
    ENROLLMENT_ID        VARCHAR(20)  NOT NULL,
    EMPLOYEE_ID             VARCHAR(20),
    PLAN_NAME                 VARCHAR(100),
    PLAN_TYPE                    VARCHAR(30),
    COVERAGE_LEVEL                  VARCHAR(50),
    COVERAGE_AMOUNT                    NUMBER(10,2),
    EFFECTIVE_DATE                       DATE,
    _FIVETRAN_SYNCED                       TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                        BOOLEAN DEFAULT FALSE
);
