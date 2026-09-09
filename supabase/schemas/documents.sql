create table documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  storage_object_id uuid not null unique references storage.objects(id) on delete cascade,
  storage_path text not null,          -- path inside "documents" bucket
  original_filename text,
  status text not null default 'pending'
    check (status in ('pending','processing','completed','failed')),
  page_count int,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table document_sections (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  page_number int not null,
  section_index int not null,          -- order within the page
  type text not null
    check(type in ('title','text','table','figure','formula','list','header','footer','other')),
  content text not null,               -- markdown for this section, image URLs already rewritten
  bbox jsonb,                          -- [x1,y1,x2,y2]
  metadata jsonb default '{}',
  created_at timestamptz not null default now(),
  unique (document_id, page_number, section_index)
);

create index on document_sections (document_id, page_number);

alter table documents enable row level security;

create policy "users read own documents"
  on documents for select
  using (user_id = auth.uid());


-- storage
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict do nothing;

create policy "users upload to own folder"
  on storage.objects for insert
  with check (bucket_id = 'documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "users read own files"
  on storage.objects for select
  using (bucket_id = 'documents' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function handle_document_upload()
returns trigger
language plpgsql
security definer
set search_path = public, storage, pgmq
as $$
declare
  v_document_id uuid;
  v_owner uuid;
begin
  v_owner := coalesce(new.owner_id::uuid, new.owner);

  insert into public.documents (user_id, storage_object_id, storage_path, original_filename)
  values (
    v_owner,
    new.id,
    new.name,
    split_part(new.name, '/', -1)   -- last path segment = filename
  )
  returning id into v_document_id;

  perform pgmq.create('ocr_processing');
  perform pgmq.send('ocr_processing', jsonb_build_object('document_id', v_document_id));

  return new;
end;
$$;

create trigger on_document_uploaded
after insert on storage.objects
for each row
when (new.bucket_id = 'documents')
execute function handle_document_upload();
