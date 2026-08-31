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

-- ----------------------------------------------------------------------------
-- Workday Student domain (Enrollment). Same Fivetran-shaped convention as
-- HCM/Payroll/Benefits above: source columns as-is + sync metadata.
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS WORKDAY_ACADEMIC_PERIODS (
    ACADEMIC_PERIOD_ID  VARCHAR(20)  NOT NULL,
    PERIOD_NAME          VARCHAR(50),
    START_DATE             DATE,
    END_DATE                 DATE,
    PERIOD_TYPE                VARCHAR(20),
    ACADEMIC_YEAR                 VARCHAR(20),
    _FIVETRAN_SYNCED                TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                 BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_PROGRAMS (
    PROGRAM_ID            VARCHAR(20)  NOT NULL,
    PROGRAM_NAME            VARCHAR(200),
    DEGREE_LEVEL               VARCHAR(30),
    ACADEMIC_UNIT                 VARCHAR(200),
    CREDIT_HOURS_REQUIRED            NUMBER(5,1),
    _FIVETRAN_SYNCED                   TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                    BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_STUDENTS (
    STUDENT_ID              VARCHAR(20)  NOT NULL,
    FIRST_NAME                 VARCHAR(100),
    LAST_NAME                     VARCHAR(100),
    BIRTH_DATE                       DATE,
    ENROLLMENT_STATUS                   VARCHAR(20),
    PROGRAM_ID                             VARCHAR(20),
    ADMIT_TERM_ID                             VARCHAR(20),
    EXPECTED_GRAD_TERM_ID                        VARCHAR(20),
    LAST_MODIFIED                                   TIMESTAMP_NTZ,
    _FIVETRAN_SYNCED                                  TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                                   BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_COURSE_REGISTRATIONS (
    REGISTRATION_ID       VARCHAR(20)  NOT NULL,
    STUDENT_ID                VARCHAR(20),
    COURSE_ID                    VARCHAR(20),
    COURSE_NAME                     VARCHAR(200),
    ACADEMIC_PERIOD_ID                 VARCHAR(20),
    CREDIT_HOURS                          NUMBER(3,1),
    GRADE                                    VARCHAR(5),
    REGISTRATION_STATUS                        VARCHAR(20),
    REGISTRATION_DATE                             DATE,
    _FIVETRAN_SYNCED                                TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                                 BOOLEAN DEFAULT FALSE
);

-- ----------------------------------------------------------------------------
-- Workday Financials domain. COST_CENTER_ID intentionally matches the
-- free-text values already in WORKDAY_DEPARTMENTS.COST_CENTER, so Finance's
-- cost center dimension conforms to HCM's department dimension.
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS WORKDAY_LEDGER_ACCOUNTS (
    GL_ACCOUNT_ID        VARCHAR(20)  NOT NULL,
    ACCOUNT_NAME            VARCHAR(200),
    ACCOUNT_TYPE               VARCHAR(20),
    ACCOUNT_CATEGORY              VARCHAR(30),
    _FIVETRAN_SYNCED                TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                 BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_COST_CENTERS (
    COST_CENTER_ID       VARCHAR(20)  NOT NULL,
    COST_CENTER_NAME        VARCHAR(200),
    DEPARTMENT_ID               VARCHAR(20),
    _FIVETRAN_SYNCED               TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS WORKDAY_GL_TRANSACTIONS (
    GL_TRANSACTION_ID     VARCHAR(20)  NOT NULL,
    JOURNAL_ENTRY_ID          VARCHAR(30),
    GL_ACCOUNT_ID                VARCHAR(20),
    COST_CENTER_ID                  VARCHAR(20),
    TRANSACTION_DATE                   DATE,
    AMOUNT                                 NUMBER(14,2),
    SOURCE_SYSTEM                            VARCHAR(20),
    SOURCE_REFERENCE                            VARCHAR(50),
    DESCRIPTION                                    VARCHAR(300),
    _FIVETRAN_SYNCED                                 TIMESTAMP_NTZ,
    _FIVETRAN_DELETED                                  BOOLEAN DEFAULT FALSE
);
