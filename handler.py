import runpod
import subprocess
import os
import uuid
import base64

WAIFU2X_BIN = "/app/waifu2x/waifu2x-ncnn-vulkan"
MODELS_DIR = "/app/waifu2x/models-cunet"

def handler(event):
    try:
        # قراءة البيانات من JSON
        input_data = event.get("input", {})
        image_b64 = input_data.get("image")
        scale = int(input_data.get("scale", 2))
        noise = int(input_data.get("noise", 2))

        if not image_b64:
            return {"error": "No image provided in input."}

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
            return {
                "error": "waifu2x failed",
                "stderr": result.stderr,
                "stdout": result.stdout
            }

        # تحويل الصورة الناتجة لـ Base64
        with open(out_path, "rb") as f:
            result_b64 = base64.b64encode(f.read()).decode("utf-8")

        return {"output": result_b64}

    except Exception as e:
        return {"error": str(e)}

# بدء السيرفر
runpod.serverless.start({"handler": handler})
