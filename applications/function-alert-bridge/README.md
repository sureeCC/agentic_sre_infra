# Function alert bridge

```text
Kibana webhook -> ReceiveKibanaAlert -> Event Hubs -> ProcessEventHubAlert -> Foundry Hosted Agent
```

The HTTP function relies on App Service Authentication and requires the
`Kibana.Alert.Send` application role. It validates JSON input, publishes it to
Event Hubs using managed identity, and returns HTTP 202 only after the send
succeeds. The Event Hubs trigger invokes the Hosted Agent using managed identity.

Required non-secret settings are shown in `local.settings.sample.json`. Never
commit a real `local.settings.json`, Entra client secret, storage key, or SAS key.

Required managed-identity roles:

- `Azure Event Hubs Data Sender` and `Azure Event Hubs Data Receiver` on the Event Hub.
- Foundry project role that permits invoking `sre-alert-postgres-hosted`.

The Hosted Agent owns the PostgreSQL write and must be idempotent.
