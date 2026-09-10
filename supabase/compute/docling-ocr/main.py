import os
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse

app = FastAPI()


@app.get("/hello")
def hello(request: Request):
    return {
        "worker": "hello-dockerfile-python",
        "path": request.url.path,
        "greeting": os.environ.get("GREETING"),
    }


@app.get("/ocr", response_class=HTMLResponse)
def ocr(_request: Request):
    from docling.document_converter import DocumentConverter

    source = "https://arxiv.org/pdf/2408.09869"  # Local path or URL
    converter = DocumentConverter()
    result = converter.convert(source)

    return result.document.export_to_html()
