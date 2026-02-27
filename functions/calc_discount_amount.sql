CREATE OR REPLACE EDITIONABLE FUNCTION "SELECTAI_AGENT"."CALC_DISCOUNT_AMOUNT" (
  p_rule_id      IN NUMBER,
  p_subtotal_amt IN NUMBER
) RETURN NUMBER
IS
  l_type         VARCHAR2(20);
  l_pct          NUMBER;
  l_fix          NUMBER;
  l_min          NUMBER;
  l_cap          NUMBER;
  l_expiry       DATE;
  l_now          DATE := SYSDATE;
  l_discount     NUMBER := 0;
BEGIN
  -- Input validation
  IF p_rule_id IS NULL OR p_subtotal_amt IS NULL OR p_subtotal_amt < 0 THEN
    RETURN 0;
  END IF;

  -- Fetch rule details, including optional cap and expiry
  BEGIN
    SELECT rule_type, pct_off, fixed_off, min_subtotal, max_discount_cap, expiry_date
      INTO l_type, l_pct, l_fix, l_min, l_cap, l_expiry
      FROM discount_rules
     WHERE rule_id = p_rule_id
       AND active_flag = 'Y';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0; -- Invalid or inactive rule
    WHEN OTHERS THEN
      RETURN 0; -- Any other error, fail safe
  END;

  -- Check for rule expiry
  IF l_expiry IS NOT NULL AND l_expiry < l_now THEN
    RETURN 0;
  END IF;

  -- Check minimum subtotal
  IF p_subtotal_amt < NVL(l_min, 0) THEN
    RETURN 0;
  END IF;

  -- Calculate discount
  IF l_type = 'PCT' THEN
    l_discount := ROUND(p_subtotal_amt * NVL(l_pct, 0), 2);
  ELSIF l_type = 'FIXED' THEN
    l_discount := LEAST(p_subtotal_amt, NVL(l_fix, 0));
  ELSE
    -- Future rule types: return 0 for unknown types
    RETURN 0;
  END IF;

  -- Apply discount cap if present
  IF l_cap IS NOT NULL AND l_cap > 0 THEN
    l_discount := LEAST(l_discount, l_cap);
  END IF;

  RETURN l_discount;
END;
/