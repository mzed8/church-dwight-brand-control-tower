from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import brands, alerts, chat, scenario

app = FastAPI(title="CHD Brand Control Tower API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(brands.router, prefix="/api")
app.include_router(alerts.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(scenario.router, prefix="/api")
