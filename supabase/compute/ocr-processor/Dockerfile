FROM public.ecr.aws/docker/library/python:3.14-slim

WORKDIR /app

RUN apt-get update \
  && apt-get install -y libgl1 libglib2.0-0 curl wget git procps \
  && rm -rf /var/lib/apt/lists/*

#COPY requirements.txt .
RUN pip install fastapi uvicorn supabase  'pgmq[async]<1.1'  PyMuPDF numpy
RUN pip install "python-doctr" --extra-index-url https://download.pytorch.org/whl/cpu
# RUN pip install docling --extra-index-url https://download.pytorch.org/whl/cpu

ENV HF_HOME=/tmp/
ENV TORCH_HOME=/tmp/

# RUN docling-tools models download

# ENV OMP_NUM_THREADS=4
# ENV DOCLING_ARTIFACTS_PATH=/root/.cache/docling/models

COPY . .

# workers-infra default maps to PORT=8080, defining on Dockerfile as fallback
ARG PORT=8080
# ENV PORT=${PORT}

# EXPOSE ${PORT}

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
