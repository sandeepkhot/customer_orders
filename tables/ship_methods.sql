CREATE TABLE ship_methods (
  ship_method     VARCHAR2(30) PRIMARY KEY,
  base_fee        NUMBER(10,2) NOT NULL,
  fee_per_kg      NUMBER(10,2) NOT NULL,
  free_over_subtotal NUMBER(10,2),
  active_flag     CHAR(1) DEFAULT 'Y' NOT NULL
);
