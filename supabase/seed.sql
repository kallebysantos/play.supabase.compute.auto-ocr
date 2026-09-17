-- documents_queue: Document OCR
select pgmq.create('documents')
where not exists (
  select 1 from pgmq.list_queues() where queue_name = 'documents'
);

-- document_sections_queue: Section embeddings
select pgmq.create('document_sections')
where not exists (
  select 1 from pgmq.list_queues() where queue_name = 'document_sections'
);

-- documents_bucket: Storage setup
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict do nothing;

