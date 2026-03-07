CREATE OR REPLACE EDITIONABLE FUNCTION "SELECTAI_AGENT"."CALC_DISCOUNT_AMOUNT" (
  p_rule_id      IN NUMBER,
  p_subtotal_amt IN NUMBER
) RETURN NUMBER
IS
  l_type        VARCHAR2(20);
  l_pct         NUMBER;
  l_fix         NUMBER;
  l_min         NUMBER;
  l_max         NUMBER;
  l_expiry      DATE;
  l_active      CHAR(1);
  l_discount    NUMBER := 0;
BEGIN
  -- Input validation
  IF p_rule_id IS NULL OR p_subtotal_amt IS NULL OR p_subtotal_amt < 0 THEN
    RETURN 0;
  END IF;

  -- Fetch rule details, including expiry and cap
  BEGIN
    SELECT rule_type, pct_off, fixed_off, min_subtotal, max_discount, expiry_date, active_flag
      INTO l_type, l_pct, l_fix, l_min, l_max, l_expiry, l_active
      FROM discount_rules
     WHERE rule_id = p_rule_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- Rule not found
      RETURN 0;
  END;

  -- Rule must be active
  IF l_active <> 'Y' THEN
    RETURN 0;
  END IF;

  -- Rule must not be expired (if expiry is set)
  IF l_expiry IS NOT NULL AND TRUNC(SYSDATE) > l_expiry THEN
    RETURN 0;
  END IF;

  -- Validation: Subtotal must meet minimum
  IF p_subtotal_amt < NVL(l_min, 0) THEN
    RETURN 0;
  END IF;

  -- Calculate discount based on rule type
  IF l_type = 'PCT' THEN
    l_discount := ROUND(p_subtotal_amt * NVL(l_pct, 0), 2);
  ELSIF l_type = 'FIXED' THEN
    l_discount := LEAST(p_subtotal_amt, NVL(l_fix, 0));
  ELSE
    -- Unknown rule type
    RETURN 0;
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
  WHEN OTHERS THEN
    -- Log or handle unexpected errors as needed
    RETURN 0;
END;
/