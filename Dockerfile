FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and Vulkan + NVIDIA drivers
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip python3 python3-pip \
    libvulkan1 mesa-vulkan-drivers vulkan-tools \
    nvidia-driver-535 nvidia-vulkan-icd-535 pciutils clinfo && \
    rm -rf /var/lib/apt/lists/*

# Install PyTorch with CUDA 12.4
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download waifu2x binary
RUN wget -O /tmp/waifu2x.zip \
    https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/20220728/waifu2x-ncnn-vulkan-20220728-ubuntu.zip && \
    unzip /tmp/waifu2x.zip -d /tmp && rm /tmp/waifu2x.zip && \
    mv /tmp/waifu2x-ncnn-vulkan-20220728-ubuntu /app/waifu2x && \
    chmod +x /app/waifu2x/waifu2x-ncnn-vulkan

# Copy handler
COPY handler.py /app/handler.py

# Environment variables for Vulkan and NVIDIA
ENV VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json
ENV VK_LAYER_PATH=/etc/vulkan/explicit_layer.d
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

# Fail early if NVIDIA ICD missing
RUN if [ ! -f /etc/vulkan/icd.d/nvidia_icd.json ]; then \
      echo "❌ NVIDIA ICD file NOT found! Vulkan may not work properly." && exit 1; \
    else \
      echo "✅ NVIDIA ICD file found. Vulkan should be available."; \
    fi

EXPOSE 80

# Startup script with runtime checks
CMD bash -c '\
    echo "🔍 Checking GPU availability..." && \
    if command -v vulkaninfo &>/dev/null; then \
        if ! vulkaninfo | grep -q "GPU id"; then \
            echo "❌ No GPU detected by Vulkan!" && exit 1; \
        else \
            echo "✅ GPU detected by Vulkan."; \
        fi; \
    else \
        echo "⚠️ vulkaninfo not available, skipping GPU check"; \
    fi && \
    echo "🧪 Running waifu2x self-test..." && \
    python3 - <<EOF
from PIL import Image
img = Image.new("RGB", (1, 1), color=(255, 255, 255))
img.save("/tmp/test.jpg", "JPEG")
EOF
    /app/waifu2x/waifu2x-ncnn-vulkan -i /tmp/test.jpg -o /tmp/test_up.jpg -s 2 -n 0 -f jpg -m /app/waifu2x/models-cunet -g 0 || { \
        echo "❌ waifu2x failed to run on GPU. Check drivers or models."; exit 1; } && \
    echo "✅ waifu2x self-test passed." && \
    uvicorn handler:app --host 0.0.0.0 --port 80 \
'
