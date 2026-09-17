# Supabase Auto OCR

## Getting started

1. Clone this repo

2. Link with your project

```bash
supabase link
```

3. Push DB schema

```bash
supabase db push
```

4. Add the compute secrets

5. Deploy the Auto OCR compute

```bash
supabase compute push
```

6. Watch your compute logs

```bash
supabase compute logs ocr-processor --follow 
```

7. Upload any pdf to `/documents` bucket

