CREATE OR REPLACE EDITIONABLE FUNCTION "SELECTAI_AGENT"."CALC_DISCOUNT_AMOUNT" (
  p_rule_id             IN NUMBER,
  p_subtotal_amt        IN NUMBER
) RETURN NUMBER
IS
  l_type        VARCHAR2(20);
  l_pct         NUMBER;
  l_fix         NUMBER;
  l_min         NUMBER;
  l_max         NUMBER;
  l_discount    NUMBER := 0;
BEGIN
  -- Fetch rule details, including max_discount (cap)
  SELECT rule_type, pct_off, fixed_off, min_subtotal, max_discount
    INTO l_type, l_pct, l_fix, l_min, l_max
    FROM discount_rules
   WHERE rule_id = p_rule_id
     AND active_flag = 'Y';

  -- Validation: Subtotal must meet minimum
  IF p_subtotal_amt < l_min THEN
    RETURN 0;
  END IF;

  -- Calculate discount based on rule type
  IF l_type = 'PCT' THEN
    l_discount := ROUND(p_subtotal_amt * l_pct, 2);
  ELSE
    l_discount := LEAST(p_subtotal_amt, l_fix);
  END IF;

  -- Cap the discount if max_discount is set
  IF l_max IS NOT NULL THEN
    l_discount := LEAST(l_discount, l_max);
  END IF;

  -- Ensure discount is not negative
  IF l_discount < 0 THEN
    l_discount := 0;
  END IF;

  RETURN l_discount;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    -- Rule not found or inactive
    RETURN 0;
  WHEN OTHERS THEN
    -- Log or handle unexpected errors as needed
    RETURN 0;
END;
/