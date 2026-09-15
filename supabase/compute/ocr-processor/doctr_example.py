from pathlib import Path

import pymupdf  # PyMuPDF
from doctr.io import DocumentFile
from doctr.models import ocr_predictor


# Load OCR model once when the service starts
ocr = ocr_predictor(
    det_arch="db_mobilenet_v3_large",
    reco_arch="crnn_mobilenet_v3_small",
    pretrained=True,
    keep_reading_order=True,
)


def has_text_layer(pdf_path: str) -> bool:
    doc = pymupdf.open(pdf_path)

    for page in doc:
        if page.get_text("text").strip():
            return True

    return False


def extract_pdf_text(pdf_path: str) -> str:

    # Fast path: native PDF text
    # if has_text_layer(pdf_path):
    if False:
        doc = pymupdf.open(pdf_path)

        pages = []
        for page in doc:
            pages.append(page.get_text("text"))

        return "\n\n".join(pages)

    # OCR path: scanned/image PDF
    pages = DocumentFile.from_pdf(pdf_path)

    result = ocr(pages)

    return result.render()


file = "./ggrc.pdf"
print("has_text_layer", has_text_layer(file))
content = extract_pdf_text(file)
print("has_text_layer", content)
