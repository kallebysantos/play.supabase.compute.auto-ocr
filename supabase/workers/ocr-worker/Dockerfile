FROM python:3.9-slim

# System deps required by paddlepaddle / opencv / pdf rasterization
RUN apt-get update && apt-get install -y --no-install-recommends \
  libgomp1 \
  libgl1 \
  libglib2.0-0 \
  poppler-utils \
  curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt "paddlex[ocr]"

# Bake PP-StructureV3 model weights into the image so containers don't
# re-download them on every cold start. This runs the pipeline's __init__,
# which triggers PaddleX to fetch and cache the sub-models under ~/.paddlex.
RUN python -c "from paddleocr import PPStructureV3; PPStructureV3()"

COPY main.py .

# Required at runtime, passed in via your platform's secrets/env config,
# not baked into the image:
#   SUPABASE_URL
#   SUPABASE_SERVICE_ROLE_KEY
#   SUPABASE_DB_URL

ENTRYPOINT ["python", "main.py"]
