CREATE OR REPLACE EDITIONABLE PACKAGE "SELECTAI_AGENT"."CHECKOUT_PKG" IS
  ------------------------------------------------------------------------------
  -- Checkout orchestration package
  --
  -- JIRA:
  --   CHECKOUT-1421: Coupon support with usage limits
  --   CHECKOUT-1588: Centralized repricing logic
  --   CHECKOUT-1603: Adjustment ledger for audit/debug
  ------------------------------------------------------------------------------

  -- Creates a new cart order for a customer and returns the new order ID
  FUNCTION create_cart_order(
    p_customer_id     IN NUMBER,
    p_ship_address_id IN NUMBER,
    p_bill_address_id IN NUMBER
  ) RETURN NUMBER;

  -- Adds a product item to an existing order (cart)
  PROCEDURE add_item(
    p_order_id   IN NUMBER,
    p_product_id IN NUMBER,
    p_quantity   IN NUMBER
  );

  -- Applies a coupon code to an order if valid
  PROCEDURE apply_coupon(
    p_order_id    IN NUMBER,
    p_coupon_code IN VARCHAR2
  );

  -- Recalculates all pricing, discounts, shipping, and tax for an order
  PROCEDURE reprice_order(
    p_order_id    IN NUMBER,
    p_ship_method IN VARCHAR2 DEFAULT 'GROUND'
  );

  -- Finalizes and submits the order, updating coupon usage and status
  PROCEDURE submit_order(
    p_order_id    IN NUMBER,
    p_ship_method IN VARCHAR2 DEFAULT 'GROUND'
  );

  -- Returns a JSON summary of the order's key fields
  FUNCTION get_order_summary(
    p_order_id IN NUMBER
  ) RETURN CLOB;
END checkout_pkg;
