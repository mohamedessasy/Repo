import os
import base64
import uuid
import subprocess
import io
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image

WAIFU2X_BIN = "/app/waifu2x-converter-cpp/build/waifu2x-converter-cpp"
MODEL_PATH = "/app/waifu2x-converter-cpp/models_rgb"  # ✅ مسار مطلق للنماذج

app = FastAPI()

class ImageRequest(BaseModel):
    image: str
    scale: int = 2
    noise: int = 0  # 0 = بدون إزالة ضوضاء

@app.get("/ping")
def ping():
    return {"status": "ok"}

@app.post("/")
def upscale(req: ImageRequest):
    try:
        if not req.image:
            return JSONResponse(content={"error": "No image provided"}, status_code=400)

        # 🖼️ حفظ الصورة كملف مؤقت
        in_path = f"/tmp/{uuid.uuid4()}.jpg"
        out_path = f"/tmp/{uuid.uuid4()}_up.jpg"

        img_bytes = base64.b64decode(req.image)
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        img.save(in_path, format="JPEG", quality=95)

        # 🔧 تجهيز الأمر باستخدام مسار مطلق للنماذج
        cmd = [
            WAIFU2X_BIN,
            "-i", in_path,
            "-o", out_path,
            "--scale-ratio", str(req.scale),
            "--noise-level", str(req.noise),
            "-m", "noise-scale",
            "--model-dir", MODEL_PATH,
            "-q", "90"
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

        with open(out_path, "rb") as f:
            result_b64 = base64.b64encode(f.read()).decode("utf-8")

        return {"output": result_b64}

    except Exception as e:
        print(f"[ERROR] Exception: {e}", flush=True)
        return JSONResponse(content={"error": str(e)}, status_code=500)

    finally:
        # 🧹 تنظيف الملفات المؤقتة
        try:
            if os.path.exists(in_path):
                os.remove(in_path)
            if os.path.exists(out_path):
                os.remove(out_path)
        except:
            pass
