-- Master runner for customer schema DDL split files
-- Execute from SQL*Plus/SQLcl while connected to target schema.

PROMPT Creating tables...
@tables/customers.sql
@tables/products.sql
@tables/tax_rates.sql
@tables/ship_methods.sql
@tables/discount_rules.sql
@tables/audit_log.sql
@tables/addresses.sql
@tables/inventory.sql
@tables/orders.sql
@tables/order_items.sql
@tables/coupons.sql
@tables/order_adjustments.sql

PROMPT Creating functions...
@functions/calc_tax_amount.sql
@functions/calc_discount_amount.sql
@functions/calc_shipping_amount.sql

PROMPT Creating package spec and body...
@packages/checkout_pkg.pks.sql
@packages/checkout_pkg.pkb.sql

PROMPT DDL deployment completed.
