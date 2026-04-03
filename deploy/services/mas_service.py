import httpx
import os
from databricks.sdk import WorkspaceClient

MAS_ENDPOINT = os.environ["DATABRICKS_MAS_ENDPOINT"]


def _get_auth() -> tuple[str, dict]:
    profile = os.getenv("DATABRICKS_PROFILE")
    w = WorkspaceClient(profile=profile) if profile else WorkspaceClient()
    host = w.config.host.rstrip("/")
    headers = w.config.authenticate()
    headers["Content-Type"] = "application/json"
    return host, headers


def _extract_final_response(data: dict) -> str:
    """Extract only the FINAL response from MAS Responses API format.

    The MAS returns multiple output items:
    - Intermediate: agent tool calls, sub-agent responses
    - Final: the last message from the supervisor with the synthesized answer

    We only want the last message's text content.
    """
    output = data.get("output", [])
    if isinstance(output, str):
        return output

    # Collect all message items (skip function_call, function_call_output, etc.)
    messages = []
    for item in output:
        if item.get("type") == "message" and item.get("role") == "assistant":
            texts = []
            for content in item.get("content", []):
                if content.get("type") in ("output_text", "text"):
                    text = content.get("text", "")
                    if text.strip():
                        texts.append(text)
            if texts:
                messages.append("\n\n".join(texts))

    # Return ONLY the last message (the final synthesized response)
    if messages:
        return messages[-1]

    # Fallback: check choices format
    choices = data.get("choices", [])
    if choices:
        return choices[0].get("message", {}).get("content", "")

    return "I received your question but couldn't generate a response."


async def chat(messages: list[dict]) -> str:
    host, headers = _get_auth()
    url = f"{host}/serving-endpoints/{MAS_ENDPOINT}/invocations"
    payload = {"input": messages}

    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(url, json=payload, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        return _extract_final_response(data)
