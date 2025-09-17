FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip git wget curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install PyTorch with CUDA 12.4
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124

# Install ESRGAN + dependencies
RUN pip install --no-cache-dir realesrgan basicsr facexlib gfpgan numpy pillow uvicorn fastapi

# Copy application code
COPY handler.py /app/handler.py

EXPOSE 80

CMD ["uvicorn", "handler:app", "--host", "0.0.0.0", "--port", "80"]
