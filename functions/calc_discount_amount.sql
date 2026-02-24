CREATE OR REPLACE FUNCTION calc_discount_amount(
  p_rule_id             IN NUMBER,
  p_subtotal_amt        IN NUMBER
) RETURN NUMBER
IS
  l_type    VARCHAR2(20);
  l_pct     NUMBER;
  l_fix     NUMBER;
  l_min     NUMBER;
BEGIN
  SELECT rule_type, pct_off, fixed_off, min_subtotal
    INTO l_type, l_pct, l_fix, l_min
    FROM discount_rules
   WHERE rule_id = p_rule_id
     AND active_flag = 'Y';

  IF p_subtotal_amt < l_min THEN
    RETURN 0;
  END IF;

  IF l_type = 'PCT' THEN
    RETURN ROUND(p_subtotal_amt * l_pct, 2);
  ELSE
    RETURN LEAST(p_subtotal_amt, l_fix);
  END IF;
END;
/

