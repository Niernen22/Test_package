--test plan
DECLARE
  l_run_id NUMBER;
BEGIN
  l_run_id := TEST_PACKAGE.TEST_RUNNER(234); -- Pass the desired v_id as an argument
  DBMS_OUTPUT.PUT_LINE('Run ID: ' || l_run_id);
END;
/
