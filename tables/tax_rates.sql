CREATE TABLE tax_rates (
  state_code      VARCHAR2(2) NOT NULL,
  effective_from  DATE NOT NULL,
  rate_pct        NUMBER(6,4) NOT NULL,
  CONSTRAINT tax_rates_pk PRIMARY KEY (state_code, effective_from)
);
