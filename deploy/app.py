from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import os

from routes import brands, alerts, chat, scenario

app = FastAPI(title="CHD Brand Control Tower")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API routes
app.include_router(brands.router, prefix="/api")
app.include_router(alerts.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(scenario.router, prefix="/api")

# Serve Flutter web build as static files
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

# Mount static assets (JS, CSS, images, fonts)
# Mount static subdirectories (only if they exist — handles missing dirs gracefully)
for _subdir in ["assets", "icons", "canvaskit"]:
    _subpath = os.path.join(STATIC_DIR, _subdir)
    if os.path.isdir(_subpath):
        app.mount(f"/{_subdir}", StaticFiles(directory=_subpath), name=_subdir)


@app.get("/landing.html")
async def landing():
    return FileResponse(os.path.join(STATIC_DIR, "landing.html"))


@app.get("/brand-logo.png")
async def logo():
    return FileResponse(os.path.join(STATIC_DIR, "brand-logo.png"))


@app.get("/flutter.js")
async def flutter_js():
    return FileResponse(os.path.join(STATIC_DIR, "flutter.js"))


@app.get("/flutter_bootstrap.js")
async def flutter_bootstrap():
    return FileResponse(os.path.join(STATIC_DIR, "flutter_bootstrap.js"))


@app.get("/flutter_service_worker.js")
async def flutter_sw():
    return FileResponse(os.path.join(STATIC_DIR, "flutter_service_worker.js"))


@app.get("/manifest.json")
async def manifest():
    return FileResponse(os.path.join(STATIC_DIR, "manifest.json"))


@app.get("/version.json")
async def version():
    return FileResponse(os.path.join(STATIC_DIR, "version.json"))


@app.get("/main.dart.js")
async def main_dart_js():
    path = os.path.join(STATIC_DIR, "main.dart.js")
    if os.path.exists(path):
        return FileResponse(path)
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))


@app.get("/favicon.png")
async def favicon():
    return FileResponse(os.path.join(STATIC_DIR, "favicon.png"))


# Root must be defined before catch-all
@app.get("/")
async def root():
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))


# Catch-all: serve index.html for Flutter client-side routing
@app.get("/{path:path}")
async def catch_all(path: str):
    # Try to serve the file directly first
    file_path = os.path.join(STATIC_DIR, path)
    if os.path.isfile(file_path):
        return FileResponse(file_path)
    # Otherwise serve index.html (Flutter handles routing)
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))
