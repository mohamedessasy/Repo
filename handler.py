import os
import uuid
import base64
import subprocess
from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.responses import JSONResponse

WAIFU2X_BIN = "/app/waifu2x/waifu2x-ncnn-vulkan"
MODELS_DIR = "/app/waifu2x/models-cunet"

app = FastAPI()

class ImageRequest(BaseModel):
    image: str
    scale: int = 2
    noise: int = 2

@app.get("/ping")
def ping():
    return {"status": "ok"}

@app.post("/")
def upscale(req: ImageRequest):
    try:
        if not req.image:
            return JSONResponse({"error": "No image provided"}, status_code=400)

        in_path = f"/tmp/{uuid.uuid4()}.png"
        out_path = f"/tmp/{uuid.uuid4()}_up.png"
        with open(in_path, "wb") as f:
            f.write(base64.b64decode(req.image))

        cmd = [
            WAIFU2X_BIN, "-i", in_path, "-o", out_path,
            "-s", str(req.scale), "-n", str(req.noise),
            "-f", "png", "-m", MODELS_DIR, "-g", "0"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0 or not os.path.exists(out_path):
            return JSONResponse(
                {"error": "waifu2x failed", "stderr": result.stderr, "stdout": result.stdout},
                status_code=500,
            )

        with open(out_path, "rb") as f:
            result_b64 = base64.b64encode(f.read()).decode("utf-8")
        return {"output": result_b64}

    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 80))  # الآن يتطابق مع إعدادات RunPod
    uvicorn.run(app, host="0.0.0.0", port=port)
