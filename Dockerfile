FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# ✅ تثبيت المكتبات الأساسية + Vulkan + X11
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip python3 python3-pip \
    libvulkan1 mesa-vulkan-drivers vulkan-tools mesa-utils \
    libx11-6 libxext6 libxau6 libxdmcp6 && \
    rm -rf /var/lib/apt/lists/*

# ✅ تثبيت PyTorch متوافق مع CUDA 12.4
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124

# ✅ تثبيت المتطلبات
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ✅ تحميل waifu2x binary
RUN wget -O /tmp/waifu2x.zip \
    https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/20220728/waifu2x-ncnn-vulkan-20220728-ubuntu.zip && \
    unzip /tmp/waifu2x.zip -d /tmp && rm /tmp/waifu2x.zip && \
    mv /tmp/waifu2x-ncnn-vulkan-20220728-ubuntu /app/waifu2x && \
    chmod +x /app/waifu2x/waifu2x-ncnn-vulkan

# ✅ نسخ الـ handler
COPY handler.py /app/handler.py

# ✅ إعداد متغيرات البيئة
ENV VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json
ENV VK_LAYER_PATH=/etc/vulkan/explicit_layer.d
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

EXPOSE 80

CMD bash -c '\
    echo "🔍 Checking GPU availability..." && \
    if command -v vulkaninfo >/dev/null 2>&1 && vulkaninfo | grep -q "GPU id"; then \
        echo "✅ GPU detected by Vulkan."; \
    else \
        echo "⚠️ Warning: Vulkan did not detect a GPU."; \
    fi && \
    echo "🧪 Running waifu2x self-test..." && \
    python3 -c "from PIL import Image; img = Image.new(\"RGB\", (1, 1), (255, 255, 255)); img.save(\"/tmp/test.jpg\", \"JPEG\")" && \
    /app/waifu2x/waifu2x-ncnn-vulkan -i /tmp/test.jpg -o /tmp/test_up.jpg -s 2 -n 0 -f jpg -m /app/waifu2x/models-cunet -g auto || { \
        echo \"❌ waifu2x failed to run! Check drivers or GPU runtime.\"; exit 1; } && \
    echo \"✅ waifu2x self-test passed.\" && \
    uvicorn handler:app --host 0.0.0.0 --port 80 \
'
