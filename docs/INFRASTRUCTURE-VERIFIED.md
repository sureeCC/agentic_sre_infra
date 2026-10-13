# Dev infrastructure verification — 2026-10-13

Personal subscription: `244b1140-2e3c-4232-8c86-2b77c04ca37e`.

- [All-unit apply succeeded](https://github.com/sureeCC/agentic_sre_infra/actions/runs/38392506951).
- [Fresh all-unit plan succeeded with no changes](https://github.com/sureeCC/agentic_sre_infra/actions/runs/38393279117).
- Managed identity, Event Hub, ACR, Key Vault, PostgreSQL and Foundry are tracked in their separate state files.
- Foundry account: `ai-agenticsre-dev-wus-002-244b11`; project: `proj-agenticsre-dev-wus-002`; deployment: `alert-agent-mini` (`gpt-5-nano`). All are provisioned successfully.
- The recovered instance 001 repeatedly failed project creation with Azure InternalServerError, including through the current management API. A fresh instance 002 succeeded. Its account/project were imported after snapshotting the remote state. The old endpoint was replaced by Terraform; the retired empty account was soft-deleted without purging.
- Four private endpoints are provisioned successfully and approved. ACR, Event Hub, Key Vault and Foundry have public access disabled. ACR admin access is disabled; Event Hub/Foundry local authentication is disabled; Key Vault uses RBAC. PostgreSQL is Ready with public access disabled and delegated subnet integration.
- Seven private DNS zones each have one VNet link. Their A records point to `10.20.1.x` endpoints or PostgreSQL's `10.20.2.4`. Foundry's endpoint zone group contains all three required DNS zones.
- Workflow lint, Bash syntax and Terragrunt formatting checks passed. The reusable modules repository was not changed for this repair.

This verifies infrastructure provisioning and management-plane DNS configuration. Application connectivity from a VNet-connected runtime has not yet been tested. No application agent was deployed by Terraform. See [next-stage prerequisites](NEXT-STAGE.md) for Function hosting, hosted-agent networking, PostgreSQL Entra authentication and application permissions.
