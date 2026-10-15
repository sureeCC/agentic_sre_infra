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

## Docker deployment

Build from this directory's Dockerfile for `linux/amd64`; the container runs as
user `agent` and serves Foundry Responses on port 8088. The CI workflow pushes a
unique image tag to ACR and deploys its immutable digest. There are no source-upload
manifests or source package helpers.

See [deployment configuration and caller example](../../docs/FOUNDRY-CONTAINER-DEPLOYMENT.md).
The runtime probe verifies image/version routing without model or database calls.
The current deployment only supplies the model setting. PostgreSQL-dependent
alert processing requires separate runtime configuration and database provisioning;
a green deployment probe does not verify the full alert processing flow.
