FROM ghcr.io/ggml-org/llama.cpp:server AS llama


FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
  PYTHONUNBUFFERED=1 \
  PIP_NO_CACHE_DIR=1 \
  PYTHONIOENCODING=UTF-8 \
  TOKENIZERS_PARALLELISM=false \
  TORCH_DEVICE=cpu \
  LLAMA_CPP_BINARY=/usr/local/bin/llama-server

WORKDIR /app


# Runtime/system dependencies commonly needed by Marker/PDF processing
# RUN apt-get update \
#   && apt-get install -y --no-install-recommends \
#   libglib2.0-0 \
#   libgl1 \
#   libgomp1 \
#   libsm6 \
#   libxext6 \
#   libxrender1 \
#   poppler-utils \
#   ca-certificates \
#   && rm -rf /var/lib/apt/lists/*

COPY --from=llama /app/llama-server /usr/local/bin/llama-server
COPY --from=llama /app/*.so* /usr/local/lib/llama/
RUN chmod +x /usr/local/bin/llama-server \
  && /usr/local/bin/llama-server --version

# Application dependencies
#COPY requirements.txt requirements.txt
RUN pip install supabase psycopg2-binary marker-pdf pillow

# Model/cache directory
# RUN mkdir -p /models/huggingface

COPY main.py main.py

CMD ["python", "-u", "/app/main.py"]
