CREATE OR REPLACE PACKAGE BODY checkout_pkg IS

  ------------------------------------------------------------------------------
  -- PROCEDURE: log_audit
  -- Purpose: Internal helper to log audit actions for entities (orders, etc.)
  -- Parameters:
  --   p_entity_type - Type of entity (e.g., 'ORDER')
  --   p_entity_id   - ID of the entity
  --   p_action      - Action performed
  --   p_detail      - Additional details about the action
  ------------------------------------------------------------------------------

  PROCEDURE log_audit(
    p_entity_type IN VARCHAR2,
    p_entity_id   IN NUMBER,
    p_action      IN VARCHAR2,
    p_detail      IN VARCHAR2
  ) IS
  BEGIN
    INSERT INTO audit_log(entity_type, entity_id, action, detail)
    VALUES (p_entity_type, p_entity_id, p_action, p_detail);
  END log_audit;

  ------------------------------------------------------------------------------
  -- FUNCTION: create_cart_order
  -- Purpose: Creates a new cart order for a customer with shipping and billing addresses.
  -- Returns: The new order_id.
  -- Parameters:
  --   p_customer_id     - Customer placing the order
  --   p_ship_address_id - Shipping address ID
  --   p_bill_address_id - Billing address ID
  ------------------------------------------------------------------------------

  FUNCTION create_cart_order(
    p_customer_id     IN NUMBER,
    p_ship_address_id IN NUMBER,
    p_bill_address_id IN NUMBER
  ) RETURN NUMBER
  IS
    l_order_id NUMBER;
  BEGIN
    INSERT INTO orders(
      customer_id,
      ship_address_id,
      bill_address_id,
      status
    )
    VALUES(
      p_customer_id,
      p_ship_address_id,
      p_bill_address_id,
      'CART'
    )
    RETURNING order_id INTO l_order_id;

    log_audit('ORDER', l_order_id, 'CREATE_CART', 'Cart created');

    RETURN l_order_id;
  END create_cart_order;

  ------------------------------------------------------------------------------
  -- PROCEDURE: add_item
  -- Purpose: Adds a product item to an order (cart), checks inventory and product status.
  -- Parameters:
  --   p_order_id   - Order to add item to
  --   p_product_id - Product to add
  --   p_quantity   - Quantity to add
  ------------------------------------------------------------------------------

  PROCEDURE add_item(
    p_order_id   IN NUMBER,
    p_product_id IN NUMBER,
    p_quantity   IN NUMBER
  ) IS
    l_price    NUMBER;
    l_taxable  CHAR(1);
    l_active   CHAR(1);
    l_on_hand  NUMBER;
  BEGIN
    SELECT unit_price, is_taxable, active_flag
      INTO l_price, l_taxable, l_active
      FROM products
     WHERE product_id = p_product_id;

    IF l_active <> 'Y' THEN
      raise_application_error(-20001, 'Product is not active');
    END IF;

    SELECT qty_on_hand
      INTO l_on_hand
      FROM inventory
     WHERE product_id = p_product_id
       FOR UPDATE;

    IF l_on_hand < p_quantity THEN
      raise_application_error(-20002, 'Insufficient inventory');
    END IF;

    INSERT INTO order_items(
      order_id,
      product_id,
      quantity,
      unit_price,
      line_subtotal,
      is_taxable
    )
    VALUES(
      p_order_id,
      p_product_id,
      p_quantity,
      l_price,
      ROUND(l_price * p_quantity, 2),
      l_taxable
    );

    UPDATE inventory
       SET qty_on_hand = qty_on_hand - p_quantity,
           updated_at  = SYSTIMESTAMP
     WHERE product_id = p_product_id;

    log_audit(
      'ORDER',
      p_order_id,
      'ADD_ITEM',
      'product_id=' || p_product_id || ', qty=' || p_quantity
    );
  END add_item;

  ------------------------------------------------------------------------------
  -- PROCEDURE: apply_coupon
  -- Purpose: Applies a coupon code to an order, validates coupon status and limits.
  -- Parameters:
  --   p_order_id    - Order to apply coupon to
  --   p_coupon_code - Coupon code to apply
  ------------------------------------------------------------------------------

  PROCEDURE apply_coupon(
    p_order_id    IN NUMBER,
    p_coupon_code IN VARCHAR2
  ) IS
    l_active   CHAR(1);
    l_from     DATE;
    l_to       DATE;
    l_max_uses NUMBER;
    l_used     NUMBER;
  BEGIN
    SELECT active_flag, valid_from, valid_to, max_uses, used_count
      INTO l_active, l_from, l_to, l_max_uses, l_used
      FROM coupons
     WHERE coupon_code = UPPER(p_coupon_code);

    IF l_active <> 'Y' THEN
      raise_application_error(-20010, 'Coupon is not active');
    END IF;

    IF SYSDATE NOT BETWEEN l_from AND l_to THEN
      raise_application_error(-20011, 'Coupon is not valid for this date');
    END IF;

    IF l_max_uses IS NOT NULL AND l_used >= l_max_uses THEN
      raise_application_error(-20012, 'Coupon usage limit reached');
    END IF;

    UPDATE orders
       SET coupon_code = UPPER(p_coupon_code),
           updated_at  = SYSTIMESTAMP
     WHERE order_id = p_order_id;

    log_audit(
      'ORDER',
      p_order_id,
      'APPLY_COUPON',
      'coupon=' || UPPER(p_coupon_code)
    );
  END apply_coupon;

  ------------------------------------------------------------------------------
  -- PROCEDURE: reprice_order
  -- Purpose: Central pricing logic to recalculate all order amounts (subtotal, discount, shipping, tax, total).
  -- Parameters:
  --   p_order_id    - Order to reprice
  --   p_ship_method - Shipping method (default 'GROUND')
  ------------------------------------------------------------------------------

  PROCEDURE reprice_order(
    p_order_id    IN NUMBER,
    p_ship_method IN VARCHAR2 DEFAULT 'GROUND'
  ) IS
    l_subtotal     NUMBER := 0;
    l_taxable_base NUMBER := 0;
    l_discount     NUMBER := 0;
    l_shipping     NUMBER := 0;
    l_tax          NUMBER := 0;
    l_weight       NUMBER := 0;
    l_state        VARCHAR2(2);
    l_coupon       VARCHAR2(40);
    l_rule_id      NUMBER;
  BEGIN
    DELETE FROM order_adjustments WHERE order_id = p_order_id;

    SELECT NVL(SUM(i.line_subtotal), 0),
           NVL(SUM(CASE WHEN i.is_taxable = 'Y' THEN i.line_subtotal ELSE 0 END), 0),
           NVL(SUM(p.weight_kg * i.quantity), 0)
      INTO l_subtotal, l_taxable_base, l_weight
      FROM order_items i
      JOIN products p ON p.product_id = i.product_id
     WHERE i.order_id = p_order_id;

    SELECT a.state_code, o.coupon_code
      INTO l_state, l_coupon
      FROM orders o
      JOIN addresses a ON a.address_id = o.ship_address_id
     WHERE o.order_id = p_order_id;

    -- Coupon discount
    IF l_coupon IS NOT NULL THEN
      SELECT rule_id
        INTO l_rule_id
        FROM coupons
       WHERE coupon_code = l_coupon;

      l_discount := calc_discount_amount(l_rule_id, l_subtotal);

      IF l_discount > 0 THEN
        INSERT INTO order_adjustments(order_id, adj_type, description, amount)
        VALUES (p_order_id, 'DISCOUNT', 'Coupon ' || l_coupon, -l_discount);
      END IF;
    END IF;

    -- Shipping
    l_shipping := calc_shipping_amount(
                    p_ship_method,
                    l_subtotal - l_discount,
                    l_weight
                  );

    IF l_shipping > 0 THEN
      INSERT INTO order_adjustments(order_id, adj_type, description, amount)
      VALUES (p_order_id, 'SHIPPING', p_ship_method, l_shipping);
    END IF;

    -- Tax (bug lives in calc_tax_amount)
    l_tax := calc_tax_amount(
               GREATEST(0, l_taxable_base - l_discount),
               l_state
             );

    IF l_tax > 0 THEN
      INSERT INTO order_adjustments(order_id, adj_type, description, amount)
      VALUES (p_order_id, 'TAX', 'State ' || l_state, l_tax);
    END IF;

    UPDATE orders
       SET subtotal_amt = ROUND(l_subtotal, 2),
           discount_amt = ROUND(l_discount, 2),
           shipping_amt = ROUND(l_shipping, 2),
           tax_amt      = ROUND(l_tax, 2),
           total_amt    = ROUND(l_subtotal - l_discount + l_shipping + l_tax, 2),
           updated_at   = SYSTIMESTAMP
     WHERE order_id = p_order_id;

    log_audit('ORDER', p_order_id, 'REPRICE', 'Order repriced');
  END reprice_order;

  ------------------------------------------------------------------------------
  -- PROCEDURE: submit_order
  -- Purpose: Finalizes and submits an order, updates coupon usage, and sets order status.
  -- Parameters:
  --   p_order_id    - Order to submit
  --   p_ship_method - Shipping method (default 'GROUND')
  ------------------------------------------------------------------------------

  PROCEDURE submit_order(
    p_order_id    IN NUMBER,
    p_ship_method IN VARCHAR2 DEFAULT 'GROUND'
  ) IS
    l_coupon VARCHAR2(40);
  BEGIN
    reprice_order(p_order_id, p_ship_method);

    SELECT coupon_code
      INTO l_coupon
      FROM orders
     WHERE order_id = p_order_id
       FOR UPDATE;

    IF l_coupon IS NOT NULL THEN
      UPDATE coupons
         SET used_count = used_count + 1
       WHERE coupon_code = l_coupon;
    END IF;

    UPDATE orders
       SET status     = 'SUBMITTED',
           updated_at = SYSTIMESTAMP
     WHERE order_id = p_order_id;

    log_audit('ORDER', p_order_id, 'SUBMIT', 'Order submitted');
  END submit_order;

  ------------------------------------------------------------------------------
  -- FUNCTION: get_order_summary
  -- Purpose: Returns a JSON summary of the order (amounts, status, coupon, etc.)
  -- Parameters:
  --   p_order_id - Order to summarize
  -- Returns: JSON CLOB with order summary
  ------------------------------------------------------------------------------

  FUNCTION get_order_summary(
    p_order_id IN NUMBER
  ) RETURN CLOB
  IS
    l_json CLOB;
  BEGIN
    SELECT JSON_OBJECT(
             'order_id'  VALUE order_id,
             'status'    VALUE status,
             'subtotal'  VALUE subtotal_amt,
             'discount'  VALUE discount_amt,
             'shipping'  VALUE shipping_amt,
             'tax'       VALUE tax_amt,
             'total'     VALUE total_amt,
             'coupon'    VALUE coupon_code
           RETURNING CLOB)
      INTO l_json
      FROM orders
     WHERE order_id = p_order_id;

    RETURN l_json;
  END get_order_summary;

END checkout_pkg;
/