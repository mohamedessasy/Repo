FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip git python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies (Real-ESRGAN + deps)
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124
RUN pip install --no-cache-dir realesrgan basicsr facexlib gfpgan numpy pillow

# Clone ESRGAN repo
RUN git clone https://github.com/xinntao/Real-ESRGAN.git /app/esrgan

# Download model (or comment out to lazy-load at runtime)
RUN mkdir -p /app/esrgan/models && \
    wget -O /app/esrgan/models/RealESRGAN_x4plus.pth \
    https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth

COPY handler.py /app/handler.py

EXPOSE 80
CMD ["uvicorn", "handler:app", "--host", "0.0.0.0", "--port", "80"]
