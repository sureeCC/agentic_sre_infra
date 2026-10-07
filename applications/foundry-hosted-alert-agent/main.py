"""Foundry Hosted Agent that analyzes and stores Kibana alerts in PostgreSQL."""

from __future__ import annotations

import asyncio
import json
import os
from contextlib import AsyncExitStack
from types import TracebackType
from typing import Annotated

import psycopg
from agent_framework import Agent, tool
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import ResponsesHostServer
from azure.ai.agentserver.core import AgentConfig, get_request_context
from azure.identity.aio import AzureCliCredential, ManagedIdentityCredential
from pydantic import Field

POSTGRES_SCOPE = "https://ossrdbms-aad.database.windows.net/.default"


def _hosted_credential() -> ManagedIdentityCredential | AzureCliCredential:
    if AgentConfig.from_env().is_hosted:
        return ManagedIdentityCredential(client_id=os.environ.get("FOUNDRY_AGENT_INSTANCE_CLIENT_ID"))
    return AzureCliCredential()


@tool(approval_mode="never_require")
async def store_alert(
    raw_payload: Annotated[str, Field(description="The original Kibana alert as a JSON string.")],
    analysis: Annotated[str, Field(description="A JSON analysis with severity, summary, recommended_action, and confidence.")],
) -> str:
    """Persist one validated Kibana alert and its SRE analysis in PostgreSQL."""
    try:
        raw_document = json.loads(raw_payload)
        analysis_document = json.loads(analysis)
    except json.JSONDecodeError as exc:
        return f"Storage rejected: both arguments must be valid JSON ({exc.msg})."

    credential = _hosted_credential()
    try:
        access_token = await credential.get_token(POSTGRES_SCOPE)
        connection_string = (
            f"host={os.environ['POSTGRES_HOST']} port=5432 "
            f"dbname={os.environ['POSTGRES_DATABASE']} "
            f"user={os.environ['POSTGRES_AAD_USER']} "
            f"password={access_token.token} sslmode=require connect_timeout=30"
        )

        def insert() -> None:
            with psycopg.connect(connection_string) as connection:
                with connection.cursor() as cursor:
                    cursor.execute(
                        "INSERT INTO public.kibana_alerts (raw_payload, agent_output) VALUES (%s::jsonb, %s::jsonb)",
                        (json.dumps(raw_document), json.dumps(analysis_document)),
                    )
                connection.commit()

        await asyncio.to_thread(insert)
        return "Stored successfully."
    finally:
        await credential.close()


def create_agent() -> Agent:
    """Create fresh request-owned clients so concurrent alert requests stay isolated."""
    credential = _hosted_credential()

    class RequestClient(FoundryChatClient):
        async def __aenter__(self) -> "RequestClient":
            return self

        async def __aexit__(
            self,
            exc_type: type[BaseException] | None,
            exc_value: BaseException | None,
            traceback: TracebackType | None,
        ) -> None:
            async with AsyncExitStack() as cleanup:
                cleanup.push_async_callback(credential.close)
                cleanup.push_async_callback(self.project_client.close)
                cleanup.push_async_callback(self.client.close)

    client = RequestClient(
        project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
        model=os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"],
        credential=credential,
        default_headers=get_request_context().platform_headers(),
    )
    return Agent(
        client=client,
        instructions=(
            "You are an SRE alert triage agent. The user sends exactly one Kibana alert JSON document. "
            "Analyze only facts present in that alert. Build valid JSON with severity, summary, "
            "recommended_action, and confidence. Then call store_alert exactly once with the original "
            "alert JSON unchanged and the JSON analysis. Do not return sensitive credentials."
        ),
        tools=[store_alert],
    )


def main() -> None:
    ResponsesHostServer(agent=create_agent, history_source="agent_server").run()


if __name__ == "__main__":
    main()
