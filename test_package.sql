CREATE OR REPLACE PACKAGE TEST_PACKAGE IS

  v_status TESTS.STATUS%TYPE;
  v_id TESTS.ID%TYPE := 234;
  v_run_id NUMBER;
  v_test_name TESTS.NAME%TYPE;

  v_schstatus VARCHAR2(20);
  v_count NUMBER := 0;
  
  v_error VARCHAR2(4000);
  v_start_time TIMESTAMP(6);
  v_end_time TIMESTAMP(6);
  v_output VARCHAR2(4000);

  PROCEDURE TEST_RUNNER;
END TEST_PACKAGE;
/
---------------------------------------------------------------------------------------------------------------------------------------  
CREATE OR REPLACE PACKAGE BODY TEST_PACKAGE IS
  v_name VARCHAR2(50);
  
  v_sqlcode TEST_STEPS.SQL_CODE%TYPE;
  v_targetuser TEST_STEPS.TARGET_USER%TYPE;

---------------------------------------------------------------------------------------------------------------------------------------  
  PROCEDURE SCHEDULER_JOBLOG IS
           BEGIN
           DBMS_SCHEDULER.create_job (
              job_name        =>  v_targetuser || '.' || v_name,
              job_type        => 'PLSQL_BLOCK',
              job_action      =>  v_sqlcode, 
              start_date      => SYSTIMESTAMP,
              repeat_interval => NULL,
              enabled         => TRUE
            );

            WHILE v_count = 0
              LOOP
                SELECT COUNT(*) INTO v_count
                FROM DBA_SCHEDULER_JOB_LOG
                WHERE job_name = upper(v_name)
                AND OWNER = v_targetuser;

                DBMS_OUTPUT.PUT_LINE('RUNNING');
                DBMS_SESSION.SLEEP(1);
              END LOOP;

                SELECT STATUS INTO v_schstatus
                FROM DBA_SCHEDULER_JOB_LOG
                WHERE job_name = UPPER(v_name)
                AND OWNER = v_targetuser;
                DBMS_OUTPUT.PUT_LINE(v_schstatus);

                
END SCHEDULER_JOBLOG;
------------------------------------------------------------------------------------------------------------------------------------------------------              
  PROCEDURE STEP_RUNNER IS
    BEGIN
        UPDATE TEST_STEPS
        SET STATUS = 'INIT'
        WHERE TEST_ID = v_id;
        COMMIT;

         FOR steporder IN (SELECT * FROM TEST_STEPS
                       WHERE TEST_ID = v_id
                       ORDER BY ORDERNUMBER)
           LOOP
           dbms_output.put_line(steporder.NAME);

           UPDATE TEST_STEPS
           SET STATUS = 'RUNNING'
           WHERE ID = steporder.id;
           COMMIT;

           --scheduled job value update         
           v_sqlcode :=steporder.SQL_CODE;
           v_targetuser :=steporder.TARGET_USER;
           v_name := to_char(steporder.name || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF'));
           DBMS_OUTPUT.PUT_LINE('Updated value: ' || v_targetuser || v_name);
           v_count := 0;
   
           --STEP_RUN_LOG STARTED
           INSERT INTO STEP_RUN_LOG (RUN_ID, STEP_ID, STEP_NAME, EVENT, EVENT_TIME, OUTPUT_MESSAGE, ERROR_MESSAGE, JOBNAME)
           VALUES (v_run_id, steporder.id, steporder.name, 'STARTED', SYSTIMESTAMP, NULL, NULL, v_targetuser || v_name);
           COMMIT;
           
--------SCHEDULER_JOBLOG PROCEDURE CALL
        TEST_PACKAGE.SCHEDULER_JOBLOG;
        
                SELECT ERRORS INTO v_error
                FROM DBA_SCHEDULER_JOB_RUN_DETAILS
                WHERE job_name = UPPER(v_name)
                AND OWNER = v_targetuser;
                DBMS_OUTPUT.PUT_LINE(v_error);
                
                SELECT LOG_DATE INTO v_end_time
                FROM DBA_SCHEDULER_JOB_RUN_DETAILS
                WHERE job_name = UPPER(v_name)
                AND OWNER = v_targetuser;
                DBMS_OUTPUT.PUT_LINE(v_end_time);
                
                SELECT ACTUAL_START_DATE INTO v_start_time
                FROM DBA_SCHEDULER_JOB_RUN_DETAILS
                WHERE job_name = UPPER(v_name)
                AND OWNER = v_targetuser;
                DBMS_OUTPUT.PUT_LINE(v_start_time);
                
                SELECT OUTPUT INTO v_output
                FROM DBA_SCHEDULER_JOB_RUN_DETAILS
                WHERE job_name = UPPER(v_name)
                AND OWNER = v_targetuser;
                DBMS_OUTPUT.PUT_LINE(v_output);
                
           UPDATE TEST_STEPS
           SET STATUS = v_schstatus, start_time = v_start_time, end_time = v_end_time
           WHERE ID = steporder.id;
           COMMIT;

           --STEP_RUN_LOG FINISHED
           INSERT INTO STEP_RUN_LOG (RUN_ID, STEP_ID, STEP_NAME, EVENT, EVENT_TIME, OUTPUT_MESSAGE, ERROR_MESSAGE, JOBNAME)
           VALUES (v_run_id, steporder.id, steporder.name, v_schstatus, SYSTIMESTAMP, v_output, v_error, v_targetuser || v_name);
           COMMIT;

         END LOOP;
   END STEP_RUNNER;
 ---------------------------------------------------------------------------------------------------------------------------------------------------------------
PROCEDURE TEST_RUNNER IS

BEGIN

  SELECT STATUS INTO v_status
  FROM TESTS
  WHERE ID = v_id;

  if v_status = 'RUNNING' THEN
    RETURN;
    END IF;

  BEGIN
    SELECT STATUS INTO v_status
    FROM TESTS
    WHERE ID = v_id
    FOR UPDATE NOWAIT;
    EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('Already locked.');
  END;
        if v_status != 'RUNNING' THEN
        SELECT run_id_seq.NEXTVAL INTO v_run_id FROM dual;
        UPDATE TESTS
        SET STATUS = 'RUNNING', RUN_ID = v_run_id
        WHERE ID = v_id;
        COMMIT;

        --VALUES
        SELECT TESTS.NAME INTO v_test_name FROM TESTS WHERE ID = v_id;

        --TEST_RUN_LOG STARTED
        INSERT INTO TEST_RUN_LOG (RUN_ID, TEST_ID, TEST_NAME, EVENT, EVENT_TIME, ERROR_MESSAGE)
        VALUES (v_run_id, v_id, v_test_name, 'STARTED', SYSTIMESTAMP, NULL);
        COMMIT;

--------STEP_RUNNER PROCEDURE CALL
        TEST_PACKAGE.STEP_RUNNER;

           UPDATE TESTS
           SET STATUS = v_schstatus, START_TIME = v_start_time, END_TIME = v_end_time
           WHERE ID = v_id;
           COMMIT;

        --TEST_RUN_LOG FINISHED
        INSERT INTO TEST_RUN_LOG (RUN_ID, TEST_ID, TEST_NAME, EVENT, EVENT_TIME, ERROR_MESSAGE)
        VALUES (v_run_id, v_id, v_test_name, v_schstatus, SYSTIMESTAMP, v_error);
        COMMIT;

        ELSE
          ROLLBACK;
       END IF;
   END TEST_RUNNER;

 END TEST_PACKAGE;
/
