CREATE TABLE coupons (
  coupon_code     VARCHAR2(40) PRIMARY KEY,
  rule_id         NUMBER NOT NULL REFERENCES discount_rules(rule_id),
  valid_from      DATE NOT NULL,
  valid_to        DATE NOT NULL,
  max_uses        NUMBER,
  used_count      NUMBER DEFAULT 0 NOT NULL,
  active_flag     CHAR(1) DEFAULT 'Y' NOT NULL
);
