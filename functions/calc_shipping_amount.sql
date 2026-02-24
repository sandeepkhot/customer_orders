CREATE OR REPLACE FUNCTION calc_shipping_amount(
  p_ship_method     IN VARCHAR2,
  p_subtotal_amt    IN NUMBER,
  p_total_weight_kg IN NUMBER
) RETURN NUMBER
IS
  l_base_fee   ship_methods.base_fee%TYPE;
  l_fee_per_kg ship_methods.fee_per_kg%TYPE;
  l_free_over  ship_methods.free_over_subtotal%TYPE;
  l_active     ship_methods.active_flag%TYPE;
  l_ship       NUMBER;
BEGIN
  SELECT base_fee, fee_per_kg, free_over_subtotal, active_flag
    INTO l_base_fee, l_fee_per_kg, l_free_over, l_active
    FROM ship_methods
   WHERE ship_method = UPPER(p_ship_method);

  IF l_active <> 'Y' THEN
    raise_application_error(-20021, 'Shipping method is not active: ' || p_ship_method);
  END IF;

  -- Free shipping threshold (if configured)
  IF l_free_over IS NOT NULL AND NVL(p_subtotal_amt,0) >= l_free_over THEN
    RETURN 0;
  END IF;

  l_ship := NVL(l_base_fee,0) + NVL(p_total_weight_kg,0) * NVL(l_fee_per_kg,0);

  RETURN ROUND(l_ship, 2);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    raise_application_error(-20020, 'Unknown shipping method: ' || p_ship_method);
END;
/


