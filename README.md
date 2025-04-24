# dba_scripts

On this repository, I'll start sharing some scripts that I use in daily basis and I've created.

## [sqlstat.sql] (https://github.com/vinidba/dba_scripts/blob/master/sqlstat.sql).

Script to check the history of performance metrics for a given SQL_ID and interval of days.

```
SQL> @sqlstat <sql_id> <number_of_days>
```

For example, to check the performance metrics for the SQL_ID b7s3d3y5sj4wr for the last 15 days.

```
SQL> @sqlstat b7s3d3y5sj4wr 15
```

## [vini_coe_load_sql_baseline.sql] (https://github.com/vinidba/dba_scripts/blob/master/vini_coe_load_sql_baseline.sql)


Script to create a SQL Plan Baseline for a SQL (Original SQL) using the Execution Plan from another SQL (Modified SQL).

This script is a modified version of coe_load_sql_baseline.sql (SQLT - Carlos Sierra) with the fo following enhancements:
1. Enhanced plan loading capability to work with plans both in memory (GV$SQL) and AWR (DBA_HIST_SQL_PLAN), providing more flexibility in plan selection
2. Uses Data Pump Export (EXPDP) instead of conventional Export (EXP) to handle tables in tablespaces encrypted with Transparent Data Encryption (TDE)

Example of usage:

```
SQL> @vini_coe_load_sql_baseline.sql

Parameter 1:
ORIGINAL_SQL_ID (required)

Enter value for 1: cvjwh9tmwcfsu

Parameter 2:
MODIFIED_SQL_ID (required)

Enter value for 2: b7s3d3y5sj4wr

Available Plan Hash Values:
Using DBA_HIST_SQLSTAT:
PHV: 1084446631 AVG_ET_SECS: .083
PHV: 2086437475 AVG_ET_SECS: .158

Parameter 3:
PLAN_HASH_VALUE (required)

Enter value for 3: 1084446631
```

### General Notes

The intent of share some SQL scripts that I'm using in daily basis, that can help you or not.

You can reach me out anytime on https://www.viniciusdba.com.br/blog


## Latest change

* 25.01 (2025-04-24)
  - Initial Version.

