FROM nvidia/cuda:12.4.0-devel-ubuntu22.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt install -y --no-install-recommends \
    git cmake build-essential libopencv-dev libpng-dev libjpeg-dev \
    curl imagemagick python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Clone and build waifu2x-converter-cpp
RUN git clone https://github.com/DeadSix27/waifu2x-converter-cpp.git /app/waifu2x-converter-cpp && \
    cd /app/waifu2x-converter-cpp && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy handler
COPY handler.py /app/handler.py

EXPOSE 80

CMD ["uvicorn", "handler:app", "--host", "0.0.0.0", "--port", "80"]
