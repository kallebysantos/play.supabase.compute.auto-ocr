from docling.document_converter import DocumentConverter
import os
import json
from supabase import create_client

DB_DSN = os.environ["SUPABASE_DB_URL"]
SUPABASE_URL = os.environ["SUPABASE_URL"]
SERVICE_ROLE_KEY = json.loads(os.environ["SUPABASE_SECRET_KEYS"])["default"]

supabase = create_client(SUPABASE_URL, SERVICE_ROLE_KEY)

print("Worker started")

# Change this to a local path or another URL if desired.
# Note: using the default URL requires network access; if offline, provide a
# local file path (e.g., Path("/path/to/file.pdf")).
source = "https://arxiv.org/pdf/2408.09869"

converter = DocumentConverter()
result = converter.convert(source)

# Print Markdown to stdout.
result.document.save_as_markdown("./result.md")

with open("./result.md", "rb") as f:
    response = supabase.storage.from_("test").upload(
        file=f,
        path="result.md",
        file_options={"cache-control": "3600", "upsert": "false"},
    )
    print("Upload: ", response.full_path)
