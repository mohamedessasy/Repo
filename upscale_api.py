from fastapi import FastAPI, UploadFile, Form
from fastapi.responses import FileResponse, JSONResponse
import uvicorn, os, subprocess, uuid

app = FastAPI()

WAIFU2X_BIN = "/app/waifu2x/waifu2x-ncnn-vulkan"
MODELS_DIR  = "/app/waifu2x/models-cunet"
OUTPUT_DIR  = "/app/api_temp"
os.makedirs(OUTPUT_DIR, exist_ok=True)

@app.get("/")
async def root():
    return {"message": "✅ Upscale API is running. Use POST /upscale to upscale images."}

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/upscale")
async def upscale_image(file: UploadFile, scale: int = Form(2), noise: int = Form(2)):
    try:
        in_path  = os.path.join(OUTPUT_DIR, f"{uuid.uuid4()}_{file.filename}")
        out_path = os.path.splitext(in_path)[0] + "_up.png"
        with open(in_path, "wb") as f:
            f.write(await file.read())

        cmd = [
            WAIFU2X_BIN, "-i", in_path, "-o", out_path,
            "-s", str(scale), "-n", str(noise),
            "-f", "png", "-m", MODELS_DIR, "-g", "0"
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)

        print("[DEBUG CMD]", " ".join(cmd))
        print("[DEBUG STDOUT]", res.stdout)
        print("[DEBUG STDERR]", res.stderr)

        if res.returncode != 0 or not os.path.exists(out_path):
            return JSONResponse({"error": "waifu2x failed", "stderr": res.stderr}, status_code=500)

        return FileResponse(out_path, media_type="image/png", filename=os.path.basename(out_path))
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)