# Foundry Hosted Alert Agent

This Python Hosted Agent receives an alert from the Function dispatcher,
produces a constrained SRE analysis, and writes the original alert plus the
analysis to `public.kibana_alerts` in PostgreSQL.

Authentication is passwordless:

- The Hosted Agent managed identity obtains a PostgreSQL Entra access token.
- The agent configuration contains only non-secret endpoint and database names.

Before deployment, create the database role for `POSTGRES_AAD_USER`, grant only
the required `INSERT` permission, and make the database write idempotent before
enabling broad retries.
