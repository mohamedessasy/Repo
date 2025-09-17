FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git python3 python3-pip \
    libglib2.0-0 libsm6 libxrender1 libxext6 && \
    rm -rf /var/lib/apt/lists/*

# Install PyTorch compatible with CUDA 12.4
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu124

# Install Real-ESRGAN
RUN pip install realesrgan

# Copy code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY handler.py /app/handler.py

EXPOSE 80
CMD ["uvicorn", "handler:app", "--host", "0.0.0.0", "--port", "80"]
