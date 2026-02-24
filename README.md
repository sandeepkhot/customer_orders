# Customer Schema DDL

This folder contains split DDL files extracted from `1.test_schema.sql`.

## Structure

- `tables/`: One file per table
- `functions/`: One file per standalone function
- `packages/`: Package spec (`.pks.sql`) and package body (`.pkb.sql`)
- `run_all.sql`: Master script to create all objects in dependency-safe order

## How to Run

1. Connect to the target Oracle schema.
2. Change directory to `ddl`.
3. Run:

```sql
@run_all.sql
```

## Notes

- `run_all.sql` assumes relative paths from inside the `ddl` directory.
- Table creation order handles foreign key dependencies.
- Package body is created after functions and package spec.
