import os, io, uuid, base64
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image
from realesrgan import RealESRGAN
import torch

app = FastAPI()

class ImageRequest(BaseModel):
    image: str
    scale: int = 2   # ESRGAN supports 2, 4
    noise: int = 0   # Ignored, ESRGAN doesn't use noise param

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

        # Load ESRGAN model once (on GPU if available)
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        model = RealESRGAN(device, scale=req.scale)
        model.load_weights(f"RealESRGAN_x{req.scale}.pth")

        upscaled = model.predict(img)

        # Save to temp path
        out_path = f"/tmp/{uuid.uuid4()}_up.jpg"
        upscaled.save(out_path, format="JPEG", quality=95)

        with open(out_path, "rb") as f:
            result_b64 = base64.b64encode(f.read()).decode("utf-8")

        return {"output": result_b64}

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)
