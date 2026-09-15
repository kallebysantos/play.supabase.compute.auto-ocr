from io import BytesIO
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption
from docling_core.types.io import DocumentStream


def init_converter():
    converter = DocumentConverter(
        allowed_formats=[InputFormat.PDF],
        format_options={
            InputFormat.PDF: PdfFormatOption(
                pipeline_options=PdfPipelineOptions(
                    generate_page_images=False, generate_picture_images=False
                )
            ),
        },
    )

    converter.initialize_pipeline(InputFormat.PDF)

    return converter


class OCR:
    def __init__(self, converter: DocumentConverter):
        self.converter = converter

    def from_stream(self, stream: bytes):
        bytes_stream = BytesIO(stream)
        doc_stream = DocumentStream(name="file.pdf", stream=bytes_stream)
        result = self.converter.convert(doc_stream)

        return result
