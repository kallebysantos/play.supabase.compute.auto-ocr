import io
import os
import time
import tempfile
import json
import psycopg2
from supabase import create_client
from paddleocr import PPStructureV3

DB_DSN = os.environ["SUPABASE_DB_URL"]
SUPABASE_URL = os.environ["SUPABASE_URL"]
SERVICE_ROLE_KEY = json.loads(os.environ["SUPABASE_SECRET_KEYS"])["default"]

DOCUMENTS_BUCKET = "documents"
ASSETS_BUCKET = "document-assets"
QUEUE_NAME = "ocr_processing"
POLL_INTERVAL_SECONDS = 2
VISIBILITY_TIMEOUT_SECONDS = 300
MAX_ATTEMPTS = 3

TYPE_MAP = {
    "paragraph_title": "title",
    "doc_title": "title",
    "text": "text",
    "table": "table",
    "figure": "figure",
    "formula": "formula",
    "header": "header",
    "footer": "footer",
}

supabase = create_client(SUPABASE_URL, SERVICE_ROLE_KEY)
pipeline = PPStructureV3(
    # Keep the first version lightweight.
    # Turn these on later if your documents need them.
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
    use_chart_recognition=False,
    use_formula_recognition=False,
    use_seal_recognition=False,
    enable_mkldnn=False,
)

print("worker started")


def read_queue(conn, qty: int = 1, vt: int = VISIBILITY_TIMEOUT_SECONDS):
    with conn.cursor() as cur:
        cur.execute("select * from pgmq.read(%s, %s, %s)", (QUEUE_NAME, vt, qty))
        rows = cur.fetchall()
    conn.commit()
    return rows


def delete_message(conn, msg_id: int):
    with conn.cursor() as cur:
        cur.execute("select pgmq.delete(%s, %s)", (QUEUE_NAME, msg_id))
    conn.commit()


def archive_message(conn, msg_id: int):
    with conn.cursor() as cur:
        cur.execute("select pgmq.archive(%s, %s)", (QUEUE_NAME, msg_id))
    conn.commit()


def process_document(document_id: str) -> None:
    doc = (
        supabase.table("documents")
        .select("*")
        .eq("id", document_id)
        .single()
        .execute()
        .data
    )
    supabase.table("documents").update({"status": "processing"}).eq(
        "id", document_id
    ).execute()
    print("processing", doc)

    with tempfile.TemporaryDirectory() as tmp:
        pdf_path = os.path.join(tmp, "input.pdf")
        with open(pdf_path, "wb") as f:
            f.write(
                supabase.storage.from_(DOCUMENTS_BUCKET).download(doc["storage_path"])
            )

        print("processing: file downloaded", pdf_path)
        results = pipeline.predict(pdf_path)

        print("processing: predict", results)

        # clear any partial rows from a previous failed attempt on this document
        supabase.table("document_sections").delete().eq(
            "document_id", document_id
        ).execute()

        section_rows = []

        for page_idx, res in enumerate(results):
            page_num = page_idx + 1
            md = res.markdown
            image_url_map = {}

            for local_path, image in md.get("markdown_images", {}).items():
                key = f"{document_id}/page-{page_num}/{os.path.basename(local_path)}"
                buf = io.BytesIO()
                image.save(buf, format="PNG")
                supabase.storage.from_(ASSETS_BUCKET).upload(
                    key,
                    buf.getvalue(),
                    {"content-type": "image/png", "upsert": "true"},
                )
                image_url_map[local_path] = supabase.storage.from_(
                    ASSETS_BUCKET
                ).get_public_url(key)

            blocks = res.json["res"]["parsing_res_list"]
            for section_idx, block in enumerate(blocks):
                content = block["block_content"]
                for local_path, public_url in image_url_map.items():
                    content = content.replace(local_path, public_url)

                section_rows.append(
                    {
                        "document_id": document_id,
                        "page_number": page_num,
                        "section_index": section_idx,
                        "type": TYPE_MAP.get(block["block_label"], "other"),
                        "content": content,
                        "bbox": block["block_bbox"],
                    }
                )

        if section_rows:
            supabase.table("document_sections").insert(section_rows).execute()

        supabase.table("documents").update(
            {"status": "completed", "page_count": len(results), "error": None}
        ).eq("id", document_id).execute()


def main() -> None:
    conn = psycopg2.connect(DB_DSN)
    print("worker started, polling queue:", QUEUE_NAME)

    while True:
        messages = read_queue(conn)

        if not messages:
            time.sleep(POLL_INTERVAL_SECONDS)
            continue

        print("read: ", messages)

        for msg_id, read_ct, enqueued_at, vt, message, headers in messages:
            document_id = message["document_id"]
            print(f"processing document {document_id} (attempt {read_ct})")

            try:
                process_document(document_id)
                delete_message(conn, msg_id)
                print(f"done: {document_id}")
            except Exception as exc:
                print(f"failed: {document_id}: {exc}")
                supabase.table("documents").update(
                    {"status": "failed", "error": str(exc)}
                ).eq("id", document_id).execute()

                if read_ct >= MAX_ATTEMPTS:
                    archive_message(conn, msg_id)
                    print(f"gave up after {read_ct} attempts: {document_id}")
                # else: leave it in the queue, it becomes visible again after vt expires


if __name__ == "__main__":
    main()
