FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip git wget unzip libvulkan1 mesa-vulkan-drivers vulkan-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Clone ESRGAN (Real-ESRGAN for example)
RUN git clone https://github.com/xinntao/Real-ESRGAN.git /app/esrgan && \
    pip install -r /app/esrgan/requirements.txt

# Download default ESRGAN model
RUN wget -O /app/esrgan/models/RealESRGAN_x4plus.pth \
    https://github.com/xinntao/Real-ESRGAN/releases/download/v0.3.0/RealESRGAN_x4plus.pth

# Copy handler
COPY handler.py /app/handler.py

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

EXPOSE 80

CMD ["uvicorn", "handler:app", "--host", "0.0.0.0", "--port", "80"]
