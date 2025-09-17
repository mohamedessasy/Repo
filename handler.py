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

# نموذج البيانات المستقبلة
class ImageRequest(BaseModel):
    image: str
    scale: int = 2
    noise: int = 2


@app.get("/ping")
def ping():
    """مسار اختبار صحة الخدمة، يستخدمه Load Balancer."""
    return {"status": "ok"}


@app.post("/")
def upscale(req: ImageRequest):
    try:
        image_b64 = req.image
        scale = int(req.scale)
        noise = int(req.noise)

        if not image_b64:
            return JSONResponse(content={"error": "No image provided in input."}, status_code=400)

        # حفظ الصورة المدخلة مؤقتاً
        in_path = f"/tmp/{uuid.uuid4()}.png"
        out_path = f"/tmp/{uuid.uuid4()}_up.png"

        with open(in_path, "wb") as f:
            f.write(base64.b64decode(image_b64))

        # أمر waifu2x
        cmd = [
            WAIFU2X_BIN,
            "-i", in_path,
            "-o", out_path,
            "-s", str(scale),
            "-n", str(noise),
            "-f", "png",
            "-m", MODELS_DIR,
            "-g", "0"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0 or not os.path.exists(out_path):
            return JSONResponse(
                content={
                    "error": "waifu2x failed",
                    "stderr": result.stderr,
                    "stdout": result.stdout
                },
                status_code=500
            )

        # تحويل الصورة الناتجة إلى Base64
        with open(out_path, "rb") as f:
            result_b64 = base64.b64encode(f.read()).decode("utf-8")

        return {"output": result_b64}

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 3000))  # RunPod يمرر PORT كمتغير بيئة
    uvicorn.run(app, host="0.0.0.0", port=port)
