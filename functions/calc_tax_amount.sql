CREATE OR REPLACE FUNCTION calc_tax_amount(
  p_taxable_amount      IN NUMBER,
  p_state_code          IN VARCHAR2,
  p_as_of_date          IN DATE DEFAULT SYSDATE
) RETURN NUMBER
IS
  l_rate NUMBER;
BEGIN
  SELECT rate_pct
    INTO l_rate
    FROM (
      SELECT rate_pct
        FROM tax_rates
       WHERE state_code = UPPER(p_state_code)
         AND effective_from <= TRUNC(p_as_of_date)
       ORDER BY effective_from DESC
    )
   WHERE ROWNUM = 1;

  RETURN TRUNC(p_taxable_amount * l_rate, 2);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 0;
END;
/


