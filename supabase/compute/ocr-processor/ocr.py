from doctr.io import Document, DocumentFile
from doctr.models import ocr_predictor
from doctr.models.predictor import OCRPredictor


def init_converter():
    # from docling.document_converter import DocumentConverter
    # converter = DocumentConverter()
    # return converter

    converter = ocr_predictor(
        det_arch="db_mobilenet_v3_large",
        reco_arch="crnn_mobilenet_v3_small",
        pretrained=True,
        keep_reading_order=True,
    )

    return converter


class OCR:
    def __init__(self, converter: OCRPredictor):
        self.converter = converter

    # def from_url(self, source: str):
    #     print("ocr: started", source)
    #     result: Document = self.converter(source)

    #     print("ocr: finished", source)
    #     return result.render()

    def from_stream(self, stream: bytes):
        print("ocr: started")

        file = DocumentFile.from_pdf(stream)
        print("ocr: file", len(file))

        result: Document = self.converter(file)
        print("ocr: result finished")

        return result
