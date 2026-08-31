# Data Dictionary: Workday → RAW → Staging → Marts

## Worker (HCM)

| Workday field | RAW column (`RAW.WORKDAY_WORKERS`) | Staging column (`stg_workday__workers`) | Mart | Notes |
|---|---|---|---|---|
| Employee_ID | `EMPLOYEE_ID` | `employee_id` | `dim_employee.employee_id` (natural key) | |
| Legal_Name_First/Last | `FIRST_NAME`,`LAST_NAME` | `first_name`,`last_name` | `dim_employee` | |
| Hire_Date | `HIRE_DATE` | `hire_date` | `dim_employee` | |
| Termination_Date | `TERMINATION_DATE` | `termination_date` | `dim_employee` | nullable |
| Worker_Status | `WORKER_STATUS` | `worker_status` | `dim_employee` | `Active`/`Terminated`/`Leave` |
| Position_ID | `POSITION_ID` | `position_id` | `dim_employee` → FK `dim_position` | |
| Supervisory_Org_ID | `DEPARTMENT_ID` | `department_id` | `dim_employee` → FK `dim_department` | |
| Manager_Employee_ID | `MANAGER_EMPLOYEE_ID` | `manager_employee_id` | `dim_employee` | self-referencing |
| Location_ID | `LOCATION_ID` | `location_id` | `dim_employee` → FK `dim_location` | |
| Compensation_Band | `COMPENSATION_BAND` | `compensation_band` | `dim_employee` | mask for non-HR roles |
| Last_Modified | `LAST_MODIFIED` | `source_last_modified` | drives SCD2 snapshot | |
| _fivetran_synced | `_FIVETRAN_SYNCED` | `_fivetran_synced` | audit column | |

## Position / Job Profile

| Workday field | RAW | Staging | Mart |
|---|---|---|---|
| Position_ID | `POSITION_ID` | `position_id` | `dim_position.position_id` |
| Job_Profile_Name | `JOB_TITLE` | `job_title` | `dim_position.job_title` |
| Job_Family | `JOB_FAMILY` | `job_family` | `dim_position.job_family` |
| Management_Level | `MANAGEMENT_LEVEL` | `management_level` | `dim_position.management_level` |
| FTE | `FTE` | `fte` | `dim_position.fte` |

## Supervisory Organization (Department)

| Workday field | RAW | Staging | Mart |
|---|---|---|---|
| Department_ID | `DEPARTMENT_ID` | `department_id` | `dim_department.department_id` |
| Department_Name | `DEPARTMENT_NAME` | `department_name` | `dim_department.department_name` |
| Cost_Center | `COST_CENTER` | `cost_center` | `dim_department.cost_center` |
| Division | `DIVISION` | `division` | `dim_department.division` |

## Location

| Workday field | RAW | Staging | Mart |
|---|---|---|---|
| Location_ID | `LOCATION_ID` | `location_id` | `dim_location.location_id` |
| Location_Name | `LOCATION_NAME` | `location_name` | `dim_location.location_name` |
| Country | `COUNTRY` | `country` | `dim_location.country` |
| Time_Zone | `TIME_ZONE` | `time_zone` | `dim_location.time_zone` |

## Time Entry

| Workday field | RAW (`WORKDAY_TIME_ENTRIES`) | Staging (`stg_workday__time_entries`) | Mart |
|---|---|---|---|
| Time_Entry_ID | `TIME_ENTRY_ID` | `time_entry_id` | `fact_hours_worked.time_entry_id` |
| Employee_ID | `EMPLOYEE_ID` | `employee_id` | FK `dim_employee` |
| Entry_Date | `ENTRY_DATE` | `entry_date` | FK `dim_date` |
| Hours_Worked | `HOURS_WORKED` | `hours_worked` | measure |
| Overtime_Hours | `OVERTIME_HOURS` | `overtime_hours` | measure |
| Time_Type | `TIME_TYPE` | `time_type` | degenerate dim on fact |

## Pay Result (Payroll)

| Workday field | RAW (`WORKDAY_PAY_RESULTS`) | Staging (`stg_workday__pay_results`) | Mart |
|---|---|---|---|
| Pay_Result_ID | `PAY_RESULT_ID` | `pay_result_id` | `fact_pay.pay_result_id` |
| Employee_ID | `EMPLOYEE_ID` | `employee_id` | FK `dim_employee` |
| Pay_Period_End_Date | `PAY_PERIOD_END_DATE` | `pay_period_end_date` | FK `dim_date` |
| Pay_Group_ID | `PAY_GROUP_ID` | `pay_group_id` | degenerate dim |
| Earning_Deduction_Code | `CODE` | `earning_deduction_code` | degenerate dim |
| Earning_Deduction_Type | `CODE_TYPE` | `code_type` | `Earning`/`Deduction` |
| Amount | `AMOUNT` | `amount` | measure (signed) |

## Benefit Election

| Workday field | RAW (`WORKDAY_BENEFITS_ENROLLMENT`) | Staging (`stg_workday__benefits_enrollment`) | Mart |
|---|---|---|---|
| Enrollment_ID | `ENROLLMENT_ID` | `enrollment_id` | `fact_benefits_enrollment.enrollment_id` |
| Employee_ID | `EMPLOYEE_ID` | `employee_id` | FK `dim_employee` |
| Plan_Name | `PLAN_NAME` | `plan_name` | degenerate dim |
| Plan_Type | `PLAN_TYPE` | `plan_type` | `Medical`/`Dental`/`Vision`/`401k` |
| Coverage_Level | `COVERAGE_LEVEL` | `coverage_level` | e.g. `Employee Only`, `Family` |
| Coverage_Amount | `COVERAGE_AMOUNT` | `coverage_amount` | semi-additive measure |
| Effective_Date | `EFFECTIVE_DATE` | `effective_date` | FK `dim_date` |

## Academic Period (Term)

| Workday field | RAW (`WORKDAY_ACADEMIC_PERIODS`) | Staging (`stg_workday__academic_periods`) | Mart |
|---|---|---|---|
| Academic_Period_ID | `ACADEMIC_PERIOD_ID` | `academic_period_id` | `dim_academic_period.academic_period_id` |
| Period_Name | `PERIOD_NAME` | `period_name` | e.g. "Fall 2026" |
| Start_Date | `START_DATE` | `start_date` | |
| End_Date | `END_DATE` | `end_date` | |
| Period_Type | `PERIOD_TYPE` | `period_type` | `Semester`/`Summer`/`Quarter` |
| Academic_Year | `ACADEMIC_YEAR` | `academic_year` | e.g. "2025-2026" |

## Program of Study

| Workday field | RAW (`WORKDAY_PROGRAMS`) | Staging (`stg_workday__programs`) | Mart |
|---|---|---|---|
| Program_ID | `PROGRAM_ID` | `program_id` | `dim_program.program_id` |
| Program_Name | `PROGRAM_NAME` | `program_name` | |
| Degree_Level | `DEGREE_LEVEL` | `degree_level` | `Bachelor`/`Master`/`Doctorate` |
| Academic_Unit | `ACADEMIC_UNIT` | `academic_unit` | free text — see architecture.md §3 for why this isn't FK'd to `dim_department` |
| Credit_Hours_Required | `CREDIT_HOURS_REQUIRED` | `credit_hours_required` | |

## Student

| Workday field | RAW (`WORKDAY_STUDENTS`) | Staging (`stg_workday__students`) | Mart | Notes |
|---|---|---|---|---|
| Student_ID | `STUDENT_ID` | `student_id` | `dim_student.student_id` (natural key) | |
| Legal_Name_First/Last | `FIRST_NAME`,`LAST_NAME` | `first_name`,`last_name` | `dim_student` | |
| Birth_Date | `BIRTH_DATE` | `birth_date` | `dim_student` | |
| Enrollment_Status | `ENROLLMENT_STATUS` | `enrollment_status` | `dim_student` | `Active`/`Withdrawn`/`Graduated`/`Leave` |
| Program_ID | `PROGRAM_ID` | `program_id` | `dim_student` → FK `dim_program` | |
| Admit_Term_ID | `ADMIT_TERM_ID` | `admit_term_id` | `dim_student` → FK `dim_academic_period` | |
| Expected_Grad_Term_ID | `EXPECTED_GRAD_TERM_ID` | `expected_grad_term_id` | `dim_student` | informational, not FK-tested |
| Last_Modified | `LAST_MODIFIED` | `source_last_modified` | drives SCD2 snapshot | |

## Course Registration (Enrollment)

| Workday field | RAW (`WORKDAY_COURSE_REGISTRATIONS`) | Staging (`stg_workday__course_registrations`) | Mart |
|---|---|---|---|
| Registration_ID | `REGISTRATION_ID` | `registration_id` | `fact_enrollment.registration_id` |
| Student_ID | `STUDENT_ID` | `student_id` | FK `dim_student` |
| Course_ID | `COURSE_ID` | `course_id` | degenerate dim |
| Course_Name | `COURSE_NAME` | `course_name` | degenerate dim |
| Academic_Period_ID | `ACADEMIC_PERIOD_ID` | `academic_period_id` | FK `dim_academic_period` |
| Credit_Hours | `CREDIT_HOURS` | `credit_hours` | measure |
| Grade | `GRADE` | `grade` | nullable until the term closes |
| Registration_Status | `REGISTRATION_STATUS` | `registration_status` | `Enrolled`/`Completed`/`Dropped`/`Withdrawn` |

## Ledger Account (Chart of Accounts)

| Workday field | RAW (`WORKDAY_LEDGER_ACCOUNTS`) | Staging (`stg_workday__ledger_accounts`) | Mart |
|---|---|---|---|
| GL_Account_ID | `GL_ACCOUNT_ID` | `gl_account_id` | `dim_gl_account.gl_account_id` |
| Account_Name | `ACCOUNT_NAME` | `account_name` | |
| Account_Type | `ACCOUNT_TYPE` | `account_type` | `Asset`/`Liability`/`Equity`/`Revenue`/`Expense` |
| Account_Category | `ACCOUNT_CATEGORY` | `account_category` | `Balance Sheet`/`Income Statement` |

## Cost Center

| Workday field | RAW (`WORKDAY_COST_CENTERS`) | Staging (`stg_workday__cost_centers`) | Mart | Notes |
|---|---|---|---|---|
| Cost_Center_ID | `COST_CENTER_ID` | `cost_center_id` | `dim_cost_center.cost_center_id` | matches the `COST_CENTER` value already on `dim_department` |
| Cost_Center_Name | `COST_CENTER_NAME` | `cost_center_name` | `dim_cost_center` | |
| Department_ID | `DEPARTMENT_ID` | `department_id` | `dim_cost_center` → FK `dim_department` | Finance↔HCM bus-matrix join |

## Journal Entry (GL Transaction)

| Workday field | RAW (`WORKDAY_GL_TRANSACTIONS`) | Staging (`stg_workday__gl_transactions`) | Mart |
|---|---|---|---|
| GL_Transaction_ID | `GL_TRANSACTION_ID` | `gl_transaction_id` | `fact_gl_transactions.gl_transaction_id` |
| Journal_Entry_ID | `JOURNAL_ENTRY_ID` | `journal_entry_id` | groups the balanced set of lines |
| GL_Account_ID | `GL_ACCOUNT_ID` | `gl_account_id` | FK `dim_gl_account` |
| Cost_Center_ID | `COST_CENTER_ID` | `cost_center_id` | FK `dim_cost_center` |
| Transaction_Date | `TRANSACTION_DATE` | `transaction_date` | FK `dim_date` |
| Amount | `AMOUNT` | `amount` | measure (signed — debit +, credit -) |
| Source_System | `SOURCE_SYSTEM` | `source_system` | `PAYROLL`/`BILLING`/`PROCUREMENT` |
| Source_Reference | `SOURCE_REFERENCE` | `source_reference` | for `PAYROLL` rows, ties back to the pay period reconciled against `fact_pay` |

## Extension points (not yet built, same pattern applies)

- Recruiting: `Job_Requisition`, `Application` → `dim_requisition`, `fact_applications`
- Compensation events: `Comp_Event` → `fact_comp_changes`
- Performance: `Review` → `fact_performance_reviews`
