CREATE TABLE inventory (
  product_id      NUMBER PRIMARY KEY REFERENCES products(product_id),
  qty_on_hand     NUMBER NOT NULL,
  updated_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT inventory_ck1 CHECK (qty_on_hand >= 0)
);
