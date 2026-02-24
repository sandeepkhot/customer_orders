CREATE OR REPLACE PACKAGE checkout_pkg IS
  ------------------------------------------------------------------------------
  -- Checkout orchestration package
  --
  -- JIRA:
  --   CHECKOUT-1421: Coupon support with usage limits
  --   CHECKOUT-1588: Centralized repricing logic
  --   CHECKOUT-1603: Adjustment ledger for audit/debug
  ------------------------------------------------------------------------------
  FUNCTION create_cart_order(
    p_customer_id     IN NUMBER,
    p_ship_address_id IN NUMBER,
    p_bill_address_id IN NUMBER
  ) RETURN NUMBER;

  PROCEDURE add_item(
    p_order_id   IN NUMBER,
    p_product_id IN NUMBER,
    p_quantity   IN NUMBER
  );

  PROCEDURE apply_coupon(
    p_order_id    IN NUMBER,
    p_coupon_code IN VARCHAR2
  );

  PROCEDURE reprice_order(
    p_order_id    IN NUMBER,
    p_ship_method IN VARCHAR2 DEFAULT 'GROUND'
  );

  PROCEDURE submit_order(
    p_order_id    IN NUMBER,
    p_ship_method IN VARCHAR2 DEFAULT 'GROUND'
  );

  FUNCTION get_order_summary(
    p_order_id IN NUMBER
  ) RETURN CLOB;
END checkout_pkg;
/


