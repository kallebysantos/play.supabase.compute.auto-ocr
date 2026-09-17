create schema if not exists "pgmq";

create extension if not exists "pgmq" with schema "pgmq";

create schema if not exists "private";

create extension if not exists "vector" with schema "public";


  create table "public"."document_sections" (
    "id" uuid not null default gen_random_uuid(),
    "document_id" uuid not null,
    "page_number" integer not null,
    "section_index" integer not null,
    "content" text not null,
    "embeddings" public.halfvec(384),
    "status" text not null default 'pending'::text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone default now()
      );



  create table "public"."documents" (
    "id" uuid not null default gen_random_uuid(),
    "storage_object_id" uuid not null,
    "original_filename" text,
    "status" text not null default 'pending'::text,
    "page_count" integer,
    "document_object_model" jsonb,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone default now()
      );

create view documents_with_storage_path
with (security_invoker=true)
as
  select documents.*, storage.objects.name as storage_object_path
  from documents
  join storage.objects
    on storage.objects.id = documents.storage_object_id;


CREATE UNIQUE INDEX document_sections_document_id_page_number_section_index_key ON public.document_sections USING btree (document_id, page_number, section_index);

CREATE INDEX document_sections_embeddings_idx ON public.document_sections USING hnsw (embeddings public.halfvec_ip_ops);

CREATE UNIQUE INDEX document_sections_pkey ON public.document_sections USING btree (id);

CREATE UNIQUE INDEX documents_pkey ON public.documents USING btree (id);

CREATE UNIQUE INDEX documents_storage_object_id_key ON public.documents USING btree (storage_object_id);

alter table "public"."document_sections" add constraint "document_sections_pkey" PRIMARY KEY using index "document_sections_pkey";

alter table "public"."documents" add constraint "documents_pkey" PRIMARY KEY using index "documents_pkey";

alter table "public"."document_sections" add constraint "document_sections_document_id_fkey" FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE CASCADE not valid;

alter table "public"."document_sections" validate constraint "document_sections_document_id_fkey";

alter table "public"."document_sections" add constraint "document_sections_document_id_page_number_section_index_key" UNIQUE using index "document_sections_document_id_page_number_section_index_key";

alter table "public"."document_sections" add constraint "document_sections_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'processed'::text]))) not valid;

alter table "public"."document_sections" validate constraint "document_sections_status_check";

alter table "public"."documents" add constraint "documents_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'processed'::text]))) not valid;

alter table "public"."documents" validate constraint "documents_status_check";

alter table "public"."documents" add constraint "documents_storage_object_id_fkey" FOREIGN KEY (storage_object_id) REFERENCES storage.objects(id) ON DELETE CASCADE not valid;

alter table "public"."documents" validate constraint "documents_storage_object_id_fkey";

alter table "public"."documents" add constraint "documents_storage_object_id_key" UNIQUE using index "documents_storage_object_id_key";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.handle_document_upload()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'storage', 'pgmq'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION private.handle_new_document_sections_batch()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION private.handle_new_documents_batch()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

grant delete on table "public"."document_sections" to "anon";

grant insert on table "public"."document_sections" to "anon";

grant references on table "public"."document_sections" to "anon";

grant select on table "public"."document_sections" to "anon";

grant trigger on table "public"."document_sections" to "anon";

grant truncate on table "public"."document_sections" to "anon";

grant update on table "public"."document_sections" to "anon";

grant delete on table "public"."document_sections" to "authenticated";

grant insert on table "public"."document_sections" to "authenticated";

grant references on table "public"."document_sections" to "authenticated";

grant select on table "public"."document_sections" to "authenticated";

grant trigger on table "public"."document_sections" to "authenticated";

grant truncate on table "public"."document_sections" to "authenticated";

grant update on table "public"."document_sections" to "authenticated";

grant delete on table "public"."document_sections" to "service_role";

grant insert on table "public"."document_sections" to "service_role";

grant references on table "public"."document_sections" to "service_role";

grant select on table "public"."document_sections" to "service_role";

grant trigger on table "public"."document_sections" to "service_role";

grant truncate on table "public"."document_sections" to "service_role";

grant update on table "public"."document_sections" to "service_role";

grant delete on table "public"."documents" to "anon";

grant insert on table "public"."documents" to "anon";

grant references on table "public"."documents" to "anon";

grant select on table "public"."documents" to "anon";

grant trigger on table "public"."documents" to "anon";

grant truncate on table "public"."documents" to "anon";

grant update on table "public"."documents" to "anon";

grant delete on table "public"."documents" to "authenticated";

grant insert on table "public"."documents" to "authenticated";

grant references on table "public"."documents" to "authenticated";

grant select on table "public"."documents" to "authenticated";

grant trigger on table "public"."documents" to "authenticated";

grant truncate on table "public"."documents" to "authenticated";

grant update on table "public"."documents" to "authenticated";

grant delete on table "public"."documents" to "service_role";

grant insert on table "public"."documents" to "service_role";

grant references on table "public"."documents" to "service_role";

grant select on table "public"."documents" to "service_role";

grant trigger on table "public"."documents" to "service_role";

grant truncate on table "public"."documents" to "service_role";

grant update on table "public"."documents" to "service_role";

CREATE TRIGGER on_new_document_section AFTER INSERT ON public.document_sections REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION private.handle_new_document_sections_batch();

CREATE TRIGGER on_new_document AFTER INSERT ON public.documents REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION private.handle_new_documents_batch();

CREATE TRIGGER on_document_uploaded AFTER INSERT ON storage.objects FOR EACH ROW WHEN ((new.bucket_id = 'documents'::text)) EXECUTE FUNCTION private.handle_document_upload();


