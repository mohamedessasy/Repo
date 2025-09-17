import os
import base64
import uuid
import io
import subprocess
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image

# Path to ESRGAN executable or Python script
ESRGAN_BIN = "/app/esrgan/run.py"  # مثال: سكربت ESRGAN في /app/esrgan
MODEL_PATH = "/app/esrgan/models/RealESRGAN_x4plus.pth"

app = FastAPI()

class ImageRequest(BaseModel):
    image: str
    scale: int = 2

@app.get("/ping")
def ping():
    return {"status": "ok"}

@app.post("/")
def upscale(req: ImageRequest):
    try:
        if not req.image:
            return JSONResponse({"error": "No image provided"}, status_code=400)

        in_path = f"/tmp/{uuid.uuid4()}.jpg"
        out_path = f"/tmp/{uuid.uuid4()}_up.jpg"

        # Decode base64 -> save image
        img_bytes = base64.b64decode(req.image)
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        img.save(in_path, format="JPEG", quality=95)

        # Run ESRGAN (Python script)
        cmd = [
            "python3", ESRGAN_BIN,
            "--input", in_path,
            "--output", out_path,
            "--model", MODEL_PATH,
            "--scale", str(req.scale)
        ]

        print(f"[DEBUG] Running: {' '.join(cmd)}", flush=True)
        result = subprocess.run(cmd, capture_output=True, text=True)
        print("[DEBUG] ESRGAN stdout:", result.stdout, flush=True)
        print("[DEBUG] ESRGAN stderr:", result.stderr, flush=True)

        if result.returncode != 0 or not os.path.exists(out_path):
            return JSONResponse(
                {"error": "ESRGAN failed", "stderr": result.stderr, "stdout": result.stdout},
                status_code=500
            )

        with open(out_path, "rb") as f:
            result_b64 = base64.b64encode(f.read()).decode("utf-8")

        return {"output": result_b64}

    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 80))
    uvicorn.run(app, host="0.0.0.0", port=port)
