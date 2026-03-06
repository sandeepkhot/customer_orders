CREATE OR REPLACE EDITIONABLE FUNCTION SELECTAI_AGENT.CALC_DISCOUNT_AMOUNT (
    p_rule_id        IN NUMBER,
    p_subtotal_amt   IN NUMBER
) RETURN NUMBER
IS
    l_type        VARCHAR2(20);
    l_pct         NUMBER;
    l_fix         NUMBER;
    l_min_amt     NUMBER;
    l_max_amt     NUMBER;
    l_active      CHAR(1);
    l_discount    NUMBER := 0;
BEGIN
    -- Input validation
    IF p_rule_id IS NULL OR p_subtotal_amt IS NULL OR p_subtotal_amt < 0 THEN
        RETURN 0;
    END IF;

    -- Fetch rule details including max_discount
    SELECT rule_type, pct_off, fixed_off, min_subtotal, max_discount, active_flag
      INTO l_type, l_pct, l_fix, l_min_amt, l_max_amt, l_active
      FROM SELECTAI_AGENT.DISCOUNT_RULES
     WHERE rule_id = p_rule_id;

    -- Validate rule is active
    IF l_active <> 'Y' THEN
        RETURN 0;
    END IF;

    -- Validate minimum subtotal
    IF l_min_amt IS NOT NULL AND p_subtotal_amt < l_min_amt THEN
        RETURN 0;
    END IF;

    -- Discount calculation with extensibility for future rule types
    IF l_type = 'PCT' THEN
        -- Percentage discount
        l_discount := ROUND(p_subtotal_amt * NVL(l_pct, 0), 2);
    ELSIF l_type = 'FIXED' THEN
        -- Fixed amount discount, capped at subtotal
        l_discount := LEAST(p_subtotal_amt, NVL(l_fix, 0));
    -- Future extensibility: add new rule types here
    -- ELSIF l_type = 'BOGO' THEN
    --     l_discount := <future logic>;
    ELSE
        -- Unknown rule type: return 0
        l_discount := 0;
    END IF;

    -- Cap discount at max_discount if specified
    IF l_max_amt IS NOT NULL AND l_max_amt > 0 THEN
        l_discount := LEAST(l_discount, l_max_amt);
    END IF;

    RETURN l_discount;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Optionally log: invalid rule_id
        RETURN 0;
    WHEN OTHERS THEN
        -- Optionally log: unexpected error
        RETURN 0;
END CALC_DISCOUNT_AMOUNT;
/