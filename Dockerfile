FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies & Vulkan
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip python3 python3-pip \
    libvulkan1 mesa-vulkan-drivers vulkan-tools \
    nvidia-driver-535 nvidia-vulkan-icd-535 && \
    rm -rf /var/lib/apt/lists/*

# Install Python requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download waifu2x binary
RUN wget -O /tmp/waifu2x.zip \
    https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/20220728/waifu2x-ncnn-vulkan-20220728-ubuntu.zip && \
    unzip /tmp/waifu2x.zip -d /tmp && rm /tmp/waifu2x.zip && \
    mv /tmp/waifu2x-ncnn-vulkan-20220728-ubuntu /app/waifu2x && \
    chmod +x /app/waifu2x/waifu2x-ncnn-vulkan

COPY handler.py /app/handler.py

# Environment variables for Vulkan & NVIDIA
ENV VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json
ENV VK_LAYER_PATH=/etc/vulkan/explicit_layer.d
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

EXPOSE 80

CMD bash -c '\
    echo "🔍 Checking GPU..." && \
    if command -v vulkaninfo >/dev/null 2>&1 && vulkaninfo | grep -q "GPU id"; then \
        echo "✅ GPU detected."; \
    else \
        echo "⚠️ GPU not detected! Vulkan may not work."; \
    fi && \
    echo "🧪 Testing waifu2x..." && \
    python3 -c "from PIL import Image; Image.new('RGB',(1,1),(255,255,255)).save('/tmp/test.jpg','JPEG')" && \
    /app/waifu2x/waifu2x-ncnn-vulkan -i /tmp/test.jpg -o /tmp/test_up.jpg -s 2 -n 0 -f jpg -m /app/waifu2x/models-cunet -g auto || { \
        echo '❌ waifu2x failed!'; exit 1; } && \
    echo "✅ waifu2x works." && \
    uvicorn handler:app --host 0.0.0.0 --port 80 \
'
