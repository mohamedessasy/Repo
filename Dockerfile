FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# 🔧 تثبيت المكتبات الأساسية + Vulkan من Mesa (للتأكد من وجود الأدوات)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip python3 python3-pip \
    libvulkan1 mesa-vulkan-drivers vulkan-tools && \
    rm -rf /var/lib/apt/lists/*

# 🔧 تثبيت PyTorch متوافق مع CUDA 12.4 (بدون مشاكل)
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124

# 🔧 تثبيت باقي المتطلبات
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 🔧 تحميل waifu2x
RUN wget -O /tmp/waifu2x.zip \
    https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/20220728/waifu2x-ncnn-vulkan-20220728-ubuntu.zip && \
    unzip /tmp/waifu2x.zip -d /tmp && rm /tmp/waifu2x.zip && \
    mv /tmp/waifu2x-ncnn-vulkan-20220728-ubuntu /app/waifu2x && \
    chmod +x /app/waifu2x/waifu2x-ncnn-vulkan

# نسخ الكود
COPY handler.py /app/handler.py

# إعداد البيئة
ENV VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json
ENV VK_LAYER_PATH=/etc/vulkan/explicit_layer.d

# اختبار أثناء الـ build (اختياري)
RUN ls -l /etc/vulkan/icd.d || echo "⚠️ No ICD found!"

EXPOSE 80
CMD ["uvicorn", "handler:app", "--host", "0.0.0.0", "--port", "80"]
