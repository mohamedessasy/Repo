import os
import base64
import io
import torch
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image
from realesrgan import RealESRGANer

app = FastAPI()

# Lazy-load ESRGAN model only once
model = None
def load_model():
    global model
    if model is None:
        print("[INFO] Loading Real-ESRGAN model...")
        model = RealESRGANer(
            model_path=None,  # Auto-download on first run
            model_name='RealESRGAN_x4plus',
            half=True if torch.cuda.is_available() else False,
            device='cuda' if torch.cuda.is_available() else 'cpu'
        )
    return model

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
            return JSONResponse(content={"error": "No image provided"}, status_code=400)

        img_bytes = base64.b64decode(req.image)
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")

        model = load_model()
        output, _ = model.enhance(img, outscale=req.scale)

        buf = io.BytesIO()
        output.save(buf, format="JPEG", quality=95)
        result_b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

        return {"output": result_b64}

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)
