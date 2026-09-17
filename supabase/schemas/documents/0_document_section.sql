create table document_sections (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  page_number int not null,
  section_index int not null,
    unique (document_id, page_number, section_index),
  content text not null,
  embeddings halfvec(384),
  status text not null default 'pending', -- Whatever it finished the embedding process
    check (status in ('pending', 'processed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

-- f16 quantinization
create index on document_sections using hnsw (embeddings halfvec_ip_ops);

create or replace function private.handle_new_document_sections_batch()
returns trigger
language plpgsql
security definer
as $$
  declare
    result bigint;
begin
  perform pgmq.create('document_sections')
  where not exists (
    select 1 from pgmq.list_queues() where queue_name = 'document_sections'
  );

  with aggregated as (
    select array_agg(jsonb_build_object('id', n.id)) as msgs
    from new_table n
  ),
  send as (
    select pgmq.send_batch('document_sections', msgs)
    from aggregated
    where msgs is not null
  )
  select count(*) from send into result;

  return null;
end;
$$;

create or replace trigger on_new_document_section
after insert on document_sections
referencing new table as new_table
  for each statement
  execute function private.handle_new_document_sections_batch();


-- alter table document_sections enable row level security;

