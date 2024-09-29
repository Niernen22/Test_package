Runs and logs (output and error messages) a test's steps based on the test's ID (given as parameter).

tables:
TESTS -- TEST_RUN_LOG
TEST_STEPS -- STEP_RUN_LOG

how to call it in oracle db:
DECLARE
  l_run_id NUMBER;
BEGIN
  l_run_id := TEST_PACKAGE.TEST_RUNNER(234); -- Pass the desired v_id as an argument
  DBMS_OUTPUT.PUT_LINE('Run ID: ' || l_run_id);
END;
/
