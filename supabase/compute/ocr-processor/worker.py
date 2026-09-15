import asyncio
import os
import json

from supabase import create_client
from pgmq.async_queue import PGMQueue

from ocr import OCR, init_converter

SUPABASE_URL = os.environ["SUPABASE_URL"]
SECRET_KEY = json.loads(os.environ["SUPABASE_SECRET_KEYS"])["default"]

OCR_WORKER_DOCUMENTS_BUCKET = os.environ.get("OCR_WORKER_DOCUMENTS_BUCKET", "documents")
OCR_WORKER_QUEUE_NAME = os.environ.get("OCR_WORKER_QUEUE_NAME ", "ocr_processing")

supabase = create_client(SUPABASE_URL, SECRET_KEY)
ocr_service = OCR(converter=init_converter())


async def process_document(document_id: str):
    print("Worker: fetching document", document_id)

    document = (
        supabase.table("documents")
        .select("storage_path")
        .eq("id", document_id)
        .maybe_single()
        .execute()
    )

    if document is None:
        return

    storage_path = document.data["storage_path"]
    if storage_path is None:
        return

    download_stream = supabase.storage.from_("documents").download(storage_path)
    print("Worker: downloaded document bytes", len(download_stream), document_id)

    print("Worker: processing document", document_id)
    result = ocr_service.from_stream(download_stream)

    print("Worker: processed document pages", len(result.pages), document_id)

    markdown = result.document.export_to_markdown(image_placeholder="")

    print("Worker: saving markdown sections", document_id)
    saved = (
        supabase.table("document_sections")
        .insert(
            {
                "document_id": document_id,
                "page_number": 0,
                "section_index": 0,
                "type": "other",
                "content": markdown,
            }
        )
        .execute()
    )

    print("Worker: saved sections", len(saved.data), document_id)


async def main():
    print("Worker: started")
    queue = PGMQueue(
        host=os.environ["OCR_WORKER_PG_HOST"],
        port=os.environ["OCR_WORKER_PG_PORT"],
        database=os.environ["OCR_WORKER_PG_DATABASE"],
        username=os.environ["OCR_WORKER_PG_USER"],
        password=os.environ["OCR_WORKER_PG_PASS"],
    )
    await queue.init()

    print("Worker: polling queue:", OCR_WORKER_QUEUE_NAME)
    while True:
        try:
            messages = await queue.read_with_poll(OCR_WORKER_QUEUE_NAME, vt=60)

            if messages is None:
                continue

            for msg in messages:
                document_id = msg.message["document_id"]
                if document_id is None:
                    continue

                print("Worker: received ", document_id)
                await process_document(document_id)

                achived = await queue.archive(OCR_WORKER_QUEUE_NAME, msg.msg_id)
                print("Worker: archived", achived, document_id)

        except Exception as exc:
            import traceback

            print("Exception", exc)
            traceback.print_exc()

        await asyncio.sleep(1)


# Run the main function
if __name__ == "__main__":
    print("Worker: loaded")
    asyncio.run(main())
