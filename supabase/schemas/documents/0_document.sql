create table documents (
  id uuid primary key default gen_random_uuid(),
  storage_object_id uuid not null unique references storage.objects(id) on delete cascade,
  original_filename text,
  status text not null default 'pending', -- Whatever it finished the OCR process
    check (status in ('pending', 'processed')),
  page_count int,
  document_object_model jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

-- alter table documents enable row level security;

/* Storage integration */
create view documents_with_storage_path
with (security_invoker=true)
as
  select documents.*, storage.objects.name as storage_object_path
  from documents
  join storage.objects
    on storage.objects.id = documents.storage_object_id;

create or replace function private.handle_document_upload()
returns trigger
language plpgsql
security definer
set search_path = public, storage, pgmq
as $$
declare
  v_document_id uuid;
begin
  insert into public.documents (storage_object_id, original_filename)
  values (
    new.id,
    new.name
  )
  returning id into v_document_id;
  return new;
end;
$$;


create trigger on_document_uploaded
after insert on storage.objects
for each row
when (new.bucket_id = 'documents')
execute function private.handle_document_upload();


/* OCR Process */

create or replace function private.handle_new_documents_batch()
returns trigger
language plpgsql
security definer
as $$
  declare
    result bigint;
begin
  perform pgmq.create('documents')
  where not exists (
    select 1 from pgmq.list_queues() where queue_name = 'documents'
  );

  with aggregated as (
    select array_agg(jsonb_build_object('document_id', n.id)) as msgs
    from new_table n
  ),
  send as (
    select pgmq.send_batch('documents', msgs)
    from aggregated
    where msgs is not null
  )
  select count(*) from send into result;

  return null;
end;
$$;

create or replace trigger on_new_document
after insert on documents
referencing new table as new_table
  for each statement
  execute function private.handle_new_documents_batch();
