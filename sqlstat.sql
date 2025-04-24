REM
REM $Header: sqlstat.sql 1.0.0 2025/03/21 marcus.v.pedro $
REM
REM Copyright (c) 2025, All rights reserved.
REM
REM AUTHOR
REM   Marcus Vinicius Miguel Pedro
REM   Accenture Enkitec Group
REM   https://www.viniciusdba.com.br/blog
REM   https://www.linkedin.com/in/viniciusdba
REM
REM SCRIPT
REM   sqlstat.sql
REM
REM DESCRIPTION
REM   This script shows the performance metrics for a given SQL_ID and interval of days
REM
REM PRE-REQUISITES
REM   1. Be granted with SELECT_ANY_DICTIONARY privilege.
REM
REM PARAMETERS
REM   1. SQL_ID (required)
REM   2. Number of Days (required)
REM
REM EXECUTION
REM   1. Connect into SQL*Plus as user with access to data dictionary
REM   2. Execute script sqlstat.sql passing parameters
REM      inline or until requested by script.
REM
REM EXAMPLE
REM   # sqlplus system
REM   SQL> START sqlstat.sql gnjy0mn4y9pbm 30
REM
REM NOTES
REM   1. This script works on 10g or higher
REM

alter session set nls_date_format='DD-MM-YYYY HH24:MI:SS';
set lines 200 pages 200

SELECT
    CAST(begin_interval_time AS DATE) sample_time
  , sql_id
  , plan_hash_value
  , executions_delta executions
  , rows_processed_delta rows_processed
  , ROUND(rows_processed_delta / NULLIF(executions_delta,0))       rows_per_exec
  , ROUND(buffer_gets_delta    / NULLIF(executions_delta,0))       lios_per_exec
  , ROUND(disk_reads_delta     / NULLIF(executions_delta,0))       blkrd_per_exec
  , ROUND(cpu_time_delta       / NULLIF(executions_delta,0)/1000) cpu_ms_per_exec
  , ROUND(elapsed_time_delta   / NULLIF(executions_delta,0)/1000) ela_ms_per_exec
  , ROUND(iowait_delta         / NULLIF(executions_delta,0)/1000) iow_ms_per_exec
  , ROUND(clwait_delta         / NULLIF(executions_delta,0)/1000) clw_ms_per_exec
  , ROUND(apwait_delta         / NULLIF(executions_delta,0)/1000) apw_ms_per_exec
  , ROUND(ccwait_delta         / NULLIF(executions_delta,0)/1000) ccw_ms_per_exec
FROM
    dba_hist_snapshot
  NATURAL JOIN
    dba_hist_sqlstat
WHERE
    begin_interval_time > SYSDATE - &2
AND sql_id = '&1'
and executions_delta > 0
ORDER BY
    sample_time
/



