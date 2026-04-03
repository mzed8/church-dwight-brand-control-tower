from fastapi import APIRouter
from pydantic import BaseModel
from services.mas_service import chat as mas_chat

router = APIRouter()


class ChatRequest(BaseModel):
    messages: list[dict]


@router.post("/chat")
async def chat(request: ChatRequest):
    response = await mas_chat(request.messages)
    return {"content": response}
