FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies: Python, Vulkan, OpenCV runtime deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip python3 python3-pip \
    libvulkan1 mesa-vulkan-drivers vulkan-tools \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 && \
    rm -rf /var/lib/apt/lists/*

# Install PyTorch (CUDA 12.4 build)
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124

# Install ESRGAN + dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir realesrgan basicsr opencv-python pillow numpy

# Copy handler
COPY handler.py /app/handler.py

# Environment variables
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV PYTHONUNBUFFERED=1

EXPOSE 80

CMD ["uvicorn", "handler:app", "--host", "0.0.0.0", "--port", "80"]
