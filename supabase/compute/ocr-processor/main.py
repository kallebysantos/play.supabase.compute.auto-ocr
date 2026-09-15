import json
import os
from fastapi import FastAPI, Request
from pydantic import BaseModel
from supabase import create_client


SUPABASE_URL = os.environ["SUPABASE_URL"]
SECRET_KEY = json.loads(os.environ["SUPABASE_SECRET_KEYS"])["default"]

app = FastAPI()
supabase = create_client(SUPABASE_URL, SECRET_KEY)


@app.get("/health")
def hello(request: Request):
    return {
        "worker": "hello-dockerfile-python",
        "path": request.url.path,
        "greeting": os.environ.get("GREETING"),
    }


class HandleOCRPayload(BaseModel):
    source: str


@app.get("/ocr")
def handle_ocr():
    from doctr.io import DocumentFile

    download_stream = supabase.storage.from_("documents").download(
        "970d0831-6e3a-4590-936a-bf6c1099da25/f0fda3ce-82da-476f-9067-ef86f517f78d/ggrc.pdf"
    )

    file = DocumentFile.from_pdf(download_stream)

    return {"len": len(file)}
