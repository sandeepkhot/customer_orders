CREATE OR REPLACE PACKAGE checkout_pkg IS
  ------------------------------------------------------------------------------
  -- Checkout orchestration package
  --
  -- JIRA:
  --   CHECKOUT-1421: Coupon support with usage limits
  --   CHECKOUT-1588: Centralized repricing logic
  --   CHECKOUT-1603: Adjustment ledger for audit/debug
  ------------------------------------------------------------------------------

  -- Creates a new cart order for the given customer and shipping/billing addresses.
  -- Returns the newly created order ID.
  FUNCTION create_cart_order(
    p_customer_id     IN NUMBER,
    p_ship_address_id IN NUMBER,
    p_bill_address_id IN NUMBER
  ) RETURN NUMBER;

  -- Adds an item to the specified order.
  -- p_order_id: The order to which the item will be added.
  -- p_product_id: The product to add.
  -- p_quantity: The quantity of the product.
  PROCEDURE add_item(
    p_order_id   IN NUMBER,
    p_product_id IN NUMBER,
    p_quantity   IN NUMBER
  );

  -- Applies a coupon code to the specified order.
  -- p_order_id: The order to which the coupon will be applied.
  -- p_coupon_code: The coupon code to apply.
  PROCEDURE apply_coupon(
    p_order_id    IN NUMBER,
    p_coupon_code IN VARCHAR2
  );

  -- Recalculates pricing for the specified order, optionally using a specific shipping method.
  -- p_order_id: The order to reprice.
  -- p_ship_method: The shipping method to use (default is 'GROUND').
  PROCEDURE reprice_order(
    p_order_id    IN NUMBER,
    p_ship_method IN VARCHAR2 DEFAULT 'GROUND'
  );

  -- Submits the specified order for processing, optionally specifying a shipping method.
  -- p_order_id: The order to submit.
  -- p_ship_method: The shipping method to use (default is 'GROUND').
  PROCEDURE submit_order(
    p_order_id    IN NUMBER,
    p_ship_method IN VARCHAR2 DEFAULT 'GROUND'
  );

  -- Retrieves a summary of the specified order as a CLOB.
  -- p_order_id: The order for which to get the summary.
  FUNCTION get_order_summary(
    p_order_id IN NUMBER
  ) RETURN CLOB;

END checkout_pkg;
/