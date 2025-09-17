import os
import base64
import uuid
import subprocess
import io
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image

WAIFU2X_BIN = "/app/waifu2x/waifu2x-ncnn-vulkan"
MODELS_DIR = "/app/waifu2x/models-cunet"

app = FastAPI()

class ImageRequest(BaseModel):
    image: str
    scale: int = 2
    noise: int = 0   # الافتراضي بدون Denoise لتجنب تغيير الألوان

@app.get("/ping")
def ping():
    return {"status": "ok"}

@app.post("/")
def upscale(req: ImageRequest):
    try:
        if not req.image:
            return JSONResponse(content={"error": "No image provided"}, status_code=400)

        # مسارات الملفات المؤقتة
        in_path = f"/tmp/{uuid.uuid4()}.jpg"
        out_path = f"/tmp/{uuid.uuid4()}_up.jpg"

        # فك Base64 وتحويل الصورة إلى RGB + حفظها كـ JPEG
        img_bytes = base64.b64decode(req.image)
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        img.save(in_path, format="JPEG", quality=95)

        # أمر waifu2x لإخراج JPEG
        cmd = [
            WAIFU2X_BIN,
            "-i", in_path,
            "-o", out_path,
            "-s", str(req.scale),
            "-n", str(req.noise),
            "-f", "jpg",
            "-m", MODELS_DIR,
            "-g", "0"
        ]

        print(f"[DEBUG] Running command: {' '.join(cmd)}", flush=True)
        result = subprocess.run(cmd, capture_output=True, text=True)

        print("[DEBUG] waifu2x stdout:", result.stdout, flush=True)
        print("[DEBUG] waifu2x stderr:", result.stderr, flush=True)

        if result.returncode != 0 or not os.path.exists(out_path):
            return JSONResponse(
                content={"error": "waifu2x failed", "stderr": result.stderr, "stdout": result.stdout},
                status_code=500
            )

        # إعادة ترميز الناتج إلى Base64
        with open(out_path, "rb") as f:
            result_b64 = base64.b64encode(f.read()).decode("utf-8")

        return {"output": result_b64}

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 80))
    print(f"[DEBUG] Starting server on port {port} ...", flush=True)
    uvicorn.run(app, host="0.0.0.0", port=port)

