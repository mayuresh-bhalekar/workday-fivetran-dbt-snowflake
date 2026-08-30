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

## Extension points (not yet built, same pattern applies)

- Recruiting: `Job_Requisition`, `Application` → `dim_requisition`, `fact_applications`
- Compensation events: `Comp_Event` → `fact_comp_changes`
- Performance: `Review` → `fact_performance_reviews`
