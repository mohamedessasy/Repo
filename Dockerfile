FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# ✅ Install base libraries, Vulkan, OpenCV runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip python3 python3-pip \
    libvulkan1 mesa-vulkan-drivers vulkan-tools \
    libgl1 libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# ✅ Install PyTorch (CUDA 12.4 build)
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124

# ✅ Install ESRGAN and dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir realesrgan basicsr opencv-python pillow numpy

# ✅ Copy handler and code
COPY handler.py /app/handler.py

# Set environment variables
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV PYTHONUNBUFFERED=1

EXPOSE 80

CMD ["uvicorn", "handler:app", "--host", "0.0.0.0", "--port", "80"]
