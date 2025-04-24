SPO coe_load_sql_baseline.log;
SET DEF ON TERM OFF ECHO ON FEED OFF VER OFF HEA ON LIN 2000 PAGES 100 LONG 8000000 LONGC 800000 TRIMS ON TI OFF TIMI OFF SERVEROUT ON SIZE 1000000 NUM 20 SQLP SQL>;
SET SERVEROUT ON SIZE UNL;

REM
REM $Header: vini_coe_load_sql_baseline.sql 1.0.0 2025/03/21 marcus.v.pedro $
REM
REM Modified version of coe_load_sql_baseline.sql (originally created by Carlos Sierra)
REM Copyright (c) 2025, All rights reserved.
REM
REM AUTHOR
REM   Marcus Vinicius Miguel Pedro
REM   Accenture Enkitec Group
REM   https://www.viniciusdba.com.br/blog
REM   https://www.linkedin.com/in/viniciusdba
REM
REM SCRIPT
REM   vini_coe_load_sql_baseline.sql
REM
REM DESCRIPTION
REM   This script is a modified version of coe_load_sql_baseline.sql with the following
REM   enhancements:
REM   1. Enhanced plan loading capability to work with plans both in memory (GV$SQL)
REM      and AWR (DBA_HIST_SQL_PLAN), providing more flexibility in plan selection
REM   2. Uses Data Pump Export (EXPDP) instead of conventional Export (EXP) to handle
REM      tables in tablespaces encrypted with Transparent Data Encryption (TDE)
REM
REM   The script loads a plan from a modified SQL into the SQL Plan Baseline of the
REM   original SQL. If a good performing plan only reproduces with CBO Hints, then
REM   you can load the plan of the modified version of the SQL into the SQL Plan
REM   Baseline of the original SQL. In other words, the original SQL can use the
REM   plan that was generated out of the SQL with hints.
REM
REM PRE-REQUISITES
REM   1. Have in cache or AWR the text for the original SQL
REM   2. Have in cache or AWR the plan for the modified SQL (usually with hints)
REM   3. Oracle Database 11g or higher
REM   4. Access to data dictionary and privileges to create SQL Plan Baselines
REM   5. Data Pump directory (data_pump_dir) with read/write permissions
REM
REM PARAMETERS
REM   1. ORIGINAL_SQL_ID (required)
REM   2. MODIFIED_SQL_ID (required)
REM   3. PLAN_HASH_VALUE (required)
REM
REM EXECUTION
REM   1. Connect into SQL*Plus as user with access to data dictionary and
REM      privileges to create SQL Plan Baselines. Do not use SYS.
REM   2. Execute script vini_coe_load_sql_baseline.sql passing parameters
REM      inline or until requested by script.
REM   3. Provide plan hash value of the modified SQL when asked.
REM
REM EXAMPLE
REM   # sqlplus system
REM   SQL> START vini_coe_load_sql_baseline.sql gnjy0mn4y9pbm b8f3mbkd8bkgh
REM   SQL> START vini_coe_load_sql_baseline.sql
REM
REM NOTES
REM   1. This script works on 11g or higher
REM   2. For a similar script for 10g use coe_load_sql_profile.sql,
REM      which uses custom SQL Profiles instead of SQL Plan Baselines
REM   3. For possible errors see coe_load_sql_baseline.log
REM   4. Use a DBA user but not SYS. Do not connect as SYS as the staging
REM      table cannot be created in SYS schema and you will receive an error:
REM      ORA-19381: cannot create staging table in SYS schema
REM   5. Requires Data Pump directory (data_pump_dir) with proper permissions
REM   6. Compatible with TDE-encrypted tablespaces
REM

SET TERM ON ECHO OFF;

-- get user
COL connected_user NEW_V connected_user FOR A30;
SELECT USER connected_user FROM DUAL;

-- Variable declarations
VAR l_count_mem NUMBER;
VAR l_count_awr NUMBER;
VAR b_snap_id NUMBER;
VAR e_snap_id NUMBER;
VAR sql_text CLOB;
VAR plan_name VARCHAR2(30);
VAR plans NUMBER;

-- Initialize bind variables
BEGIN
  :l_count_mem := 0;
  :l_count_awr := 0;
  :b_snap_id := 0;
  :e_snap_id := 0;
  :sql_text := NULL;
  :plan_name := NULL;
  :plans := 0;
END;
/

PRO
PRO Parameter 1:
PRO ORIGINAL_SQL_ID (required)
PRO
DEF original_sql_id = '&1';
PRO
PRO Parameter 2:
PRO MODIFIED_SQL_ID (required)
PRO
DEF modified_sql_id = '&2';
PRO

-- Show available plan hash values before asking for Parameter 3
PRO Available Plan Hash Values:

DECLARE
  v_count_mem NUMBER;
  v_count_awr NUMBER;
  v_b_snap_id NUMBER;
  v_e_snap_id NUMBER;

  CURSOR cur_mem IS
    WITH
    p AS (
      SELECT DISTINCT plan_hash_value
      FROM gv$sql_plan
      WHERE sql_id = TRIM('&&modified_sql_id.')
        AND other_xml IS NOT NULL
    ),
    m AS (
      SELECT plan_hash_value,
             SUM(elapsed_time)/SUM(executions) avg_et_secs
        FROM gv$sql
       WHERE sql_id = TRIM('&&modified_sql_id.')
         AND executions > 0
       GROUP BY plan_hash_value
    )
    SELECT p.plan_hash_value,
           ROUND(m.avg_et_secs/1e6, 3) avg_et_secs
      FROM p, m
     WHERE p.plan_hash_value = m.plan_hash_value
     ORDER BY avg_et_secs NULLS LAST;

  CURSOR cur_awr IS
    WITH
    p AS (
      SELECT DISTINCT plan_hash_value
      FROM dba_hist_sql_plan
      WHERE sql_id = TRIM('&&modified_sql_id.')
        AND other_xml IS NOT NULL
    ),
    m AS (
      SELECT plan_hash_value,
             SUM(elapsed_time_delta)/SUM(executions_delta) avg_et_secs
      FROM dba_hist_sqlstat
      WHERE sql_id = TRIM('&&modified_sql_id.')
        AND executions_delta > 0
      GROUP BY plan_hash_value
    )
    SELECT p.plan_hash_value,
           ROUND(m.avg_et_secs/1e6, 3) avg_et_secs
      FROM p, m
     WHERE p.plan_hash_value = m.plan_hash_value
     ORDER BY avg_et_secs NULLS LAST;

BEGIN
  -- Check GV$SQL
  SELECT COUNT(*)
    INTO v_count_mem
    FROM gv$sql
   WHERE sql_id = TRIM('&&modified_sql_id.')
     AND executions > 0;

  IF v_count_mem > 0 THEN
    DBMS_OUTPUT.PUT_LINE('Using GV$SQL:');
    FOR rec IN cur_mem LOOP
      DBMS_OUTPUT.PUT_LINE('PHV: ' || rec.plan_hash_value || '  AVG_ET_SECS: ' || rec.avg_et_secs);
    END LOOP;
  ELSE
    -- Check AWR
    SELECT COUNT(*)
      INTO v_count_awr
      FROM dba_hist_sqlstat
     WHERE sql_id = TRIM('&&modified_sql_id.')
       AND executions_delta > 0;

    IF v_count_awr > 0 THEN
      DBMS_OUTPUT.PUT_LINE('Using DBA_HIST_SQLSTAT:');
      FOR rec IN cur_awr LOOP
        DBMS_OUTPUT.PUT_LINE('PHV: ' || rec.plan_hash_value || '  AVG_ET_SECS: ' || rec.avg_et_secs);
      END LOOP;
    ELSE
      DBMS_OUTPUT.PUT_LINE('SQL_ID not found in GV$SQL or DBA_HIST_SQLSTAT.');
    END IF;
  END IF;

  -- Set bind variables
  :l_count_mem := v_count_mem;
  :l_count_awr := v_count_awr;
END;
/

PRO
PRO Parameter 3:
PRO PLAN_HASH_VALUE (required)
PRO
DEF plan_hash_value = '&3';

-- Now get the snap_ids after we have the plan_hash_value
DECLARE
  v_min_snap_id NUMBER;
  v_max_snap_id NUMBER;
BEGIN
  IF :l_count_mem = 0 AND :l_count_awr > 0 THEN
    -- Find the snap_id range where this plan_hash_value exists
    SELECT MIN(snap_id), MAX(snap_id)
      INTO v_min_snap_id, v_max_snap_id
      FROM dba_hist_sqlstat
     WHERE sql_id = TRIM('&&modified_sql_id.')
       AND plan_hash_value = TO_NUMBER(TRIM('&&plan_hash_value.'))
       AND executions_delta > 0;

    IF v_min_snap_id IS NOT NULL THEN
      :b_snap_id := v_min_snap_id;
      :e_snap_id := v_max_snap_id;
      DBMS_OUTPUT.PUT_LINE('Found plan in AWR between snap_ids: ' || v_min_snap_id || ' and ' || v_max_snap_id);
    ELSE
      DBMS_OUTPUT.PUT_LINE('Warning: Plan hash value not found in AWR.');
    END IF;
  END IF;
END;
/

SET ECHO OFF;
DECLARE
  sys_sql_handle VARCHAR2(30);
  sys_plan_name VARCHAR2(30);
  v_table_name VARCHAR2(100);
  v_plans NUMBER;
BEGIN
  -- create sql_plan_baseline for original sql using plan from modified sql
  IF :l_count_mem > 0 THEN
    :plans := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE (
      sql_id          => TRIM('&&modified_sql_id.'),
      plan_hash_value => TO_NUMBER(TRIM('&&plan_hash_value.')),
      sql_text        => :sql_text );
    DBMS_OUTPUT.PUT_LINE('Plans Loaded from cursor cache: ' || TO_CHAR(:plans));

  ELSIF :l_count_awr > 0 THEN
    DECLARE
      baseline_ref_cursor DBMS_SQLTUNE.SQLSET_CURSOR;
    BEGIN
      -- Drop STS if exists
      BEGIN
        DBMS_SQLTUNE.DROP_SQLSET('STS_&&original_sql_id.');
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;

      -- Create STS
      DBMS_SQLTUNE.CREATE_SQLSET('STS_&&original_sql_id.');

      -- Get AWR data using the reference cursor approach
      OPEN baseline_ref_cursor FOR
        SELECT VALUE(p) 
        FROM TABLE(
          DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY(
            :b_snap_id, 
            :e_snap_id,
            'sql_id=' || CHR(39) || TRIM('&&modified_sql_id.') || CHR(39) || 
            ' AND plan_hash_value=' || TO_NUMBER(TRIM('&&plan_hash_value.')),
            NULL, NULL, NULL, NULL, NULL, NULL, 'ALL'
          )
        ) p;

      -- Load AWR data into STS
      DBMS_SQLTUNE.LOAD_SQLSET(
        sqlset_name => 'STS_&&original_sql_id.',
        populate_cursor => baseline_ref_cursor
      );

      -- Create baseline from STS
      v_plans := DBMS_SPM.LOAD_PLANS_FROM_SQLSET(
        sqlset_name => 'STS_&&original_sql_id.',
        sqlset_owner => USER,
        fixed => 'NO',
        enabled => 'YES'
      );

      -- Cleanup
      DBMS_SQLTUNE.DROP_SQLSET('STS_&&original_sql_id.');

      -- Store result
      :plans := v_plans;
      DBMS_OUTPUT.PUT_LINE('Plans Loaded from AWR: ' || TO_CHAR(:plans));
    END;
  ELSE
    DBMS_OUTPUT.PUT_LINE('No plans found in either cursor cache or AWR');
  END IF;

  -- find handle and plan_name for sql_plan_baseline just created
  SELECT sql_handle, plan_name
    INTO sys_sql_handle, sys_plan_name
    FROM dba_sql_plan_baselines
   WHERE creator = USER
     AND origin like 'MANUAL-LOAD%'
     AND created = (
         SELECT MAX(created)
           FROM dba_sql_plan_baselines
          WHERE creator = USER
            AND origin like 'MANUAL-LOAD%'
            AND created > SYSDATE - (1/24/60)
     );

  DBMS_OUTPUT.PUT_LINE('sys_sql_handle: "' || sys_sql_handle || '"');
  DBMS_OUTPUT.PUT_LINE('sys_plan_name: "' || sys_plan_name || '"');

  -- update description of new sql_plan_baseline
  :plan_name := UPPER(TRIM('&&original_sql_id.') || '_' || TRIM('&&modified_sql_id.'));
  :plan_name := sys_plan_name; -- avoids ORA-38141

  IF :plan_name <> sys_plan_name THEN
    v_plans := DBMS_SPM.ALTER_SQL_PLAN_BASELINE(
      sql_handle      => sys_sql_handle,
      plan_name       => sys_plan_name,
      attribute_name  => 'plan_name',
      attribute_value => :plan_name
    );
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(v_plans) || ' plan(s) modified plan_name: "' || :plan_name || '"');
  END IF;

  -- update description of new sql_plan_baseline
  DECLARE
    v_description VARCHAR2(500);
  BEGIN
    v_description := UPPER('original:' || TRIM('&&original_sql_id.') || 
                          ' modified:' || TRIM('&&modified_sql_id.') || 
                          ' phv:' || TRIM('&&plan_hash_value.') || 
                          ' created by vini_coe_load_sql_baseline.sql');
    
    v_plans := DBMS_SPM.ALTER_SQL_PLAN_BASELINE(
      sql_handle      => sys_sql_handle,
      plan_name       => sys_plan_name,
      attribute_name  => 'description',
      attribute_value => v_description
    );
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(v_plans) || ' plan(s) modified description: "' || v_description || '"');
  END;

  -- drop baseline staging table for original sql (if one exists)
  v_table_name := 'STGTAB_BASELINE_' || UPPER(TRIM('&&original_sql_id.'));
  BEGIN
    DBMS_OUTPUT.PUT_LINE('dropping staging table "' || v_table_name || '"');
    EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_name;
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('staging table "' || v_table_name || '" did not exist');
  END;

  -- create baseline staging table for original sql
  DBMS_OUTPUT.PUT_LINE('creating staging table "' || v_table_name || '"');
  DBMS_SPM.CREATE_STGTAB_BASELINE(
    table_name  => v_table_name,
    table_owner => '&&connected_user.'
  );

  -- packs new baseline for original sql
  DBMS_OUTPUT.PUT_LINE('packaging new sql baseline into staging table "' || v_table_name || '"');
  v_plans := DBMS_SPM.PACK_STGTAB_BASELINE(
    table_name  => v_table_name,
    table_owner => '&&connected_user.',
    sql_handle  => sys_sql_handle,
    plan_name   => :plan_name
  );
  DBMS_OUTPUT.PUT_LINE(TO_CHAR(v_plans) || ' plan(s) packaged');
END;
/

-- display details of new sql_plan_baseline
SET ECHO ON;
REM
REM SQL Plan Baseline
REM ~~~~~~~~~~~~~~~~~
REM
SELECT signature, sql_handle, plan_name, enabled, accepted, fixed--, reproduced (avail on 11.2.0.2)
  FROM dba_sql_plan_baselines WHERE plan_name = :plan_name;
SELECT description
  FROM dba_sql_plan_baselines WHERE plan_name = :plan_name;
SET ECHO OFF;
PRO
PRO ****************************************************************************
PRO * Enter &&connected_user. password to export staging table STGTAB_BASELINE_&&original_sql_id.
PRO ****************************************************************************
HOS expdp &&connected_user. tables=&&connected_user..STGTAB_BASELINE_&&original_sql_id. directory=data_pump_dir dumpfile=STGTAB_BASELINE_&&original_sql_id..dmp logfile=exp_STGTAB_BASELINE_&&original_sql_id..log exclude=index,constraint,grant,trigger,statistics
PRO
PRO If you need to implement this SQL Plan Baseline on a similar system,
PRO import and unpack using these commands:
PRO
PRO impdp userid=&&connected_user. tables=STGTAB_BASELINE_&&original_sql_id. directory=data_pump_dir dumpfile=STGTAB_BASELINE_&&original_sql_id..dmp logfile=imp_STGTAB_BASELINE_&&original_sql_id..log table_exists_action=truncate
PRO
PRO SET SERVEROUT ON;;
PRO DECLARE
PRO   plans NUMBER;;
PRO BEGIN
PRO   plans := DBMS_SPM.UNPACK_STGTAB_BASELINE('STGTAB_BASELINE_&&original_sql_id.', '&&connected_user.');;
PRO   DBMS_OUTPUT.PUT_LINE(plans||' plan(s) unpackaged');;
PRO END;;
PRO /
PRO
SPO OFF;
HOS zip -m coe_load_sql_baseline_&&original_sql_id. coe_load_sql_baseline_&&original_sql_id..log STGTAB_BASELINE_&&original_sql_id..dmp coe_load_sql_baseline.log
HOS zip -d coe_load_sql_baseline_&&original_sql_id. coe_load_sql_baseline.log
WHENEVER SQLERROR CONTINUE;
SET DEF ON TERM ON ECHO OFF FEED 6 VER ON HEA ON LIN 80 PAGES 14 LONG 80 LONGC 80 TRIMS OFF TI OFF TIMI OFF SERVEROUT OFF NUM 10 SQLP SQL>;
SET SERVEROUT OFF;
UNDEFINE 1 2 3 original_sql_id modified_sql_id plan_hash_value
CL COL
PRO
PRO vini_coe_load_sql_baseline completed.
