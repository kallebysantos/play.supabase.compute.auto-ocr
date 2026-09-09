
  create table "public"."document_sections" (
    "id" uuid not null default gen_random_uuid(),
    "document_id" uuid not null,
    "page_number" integer not null,
    "section_index" integer not null,
    "type" text not null,
    "content" text not null,
    "bbox" jsonb,
    "metadata" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."documents" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "storage_object_id" uuid not null,
    "storage_path" text not null,
    "original_filename" text,
    "status" text not null default 'pending'::text,
    "page_count" integer,
    "error" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."documents" enable row level security;

CREATE INDEX document_sections_document_id_page_number_idx ON public.document_sections USING btree (document_id, page_number);

CREATE UNIQUE INDEX document_sections_document_id_page_number_section_index_key ON public.document_sections USING btree (document_id, page_number, section_index);

CREATE UNIQUE INDEX document_sections_pkey ON public.document_sections USING btree (id);

CREATE UNIQUE INDEX documents_pkey ON public.documents USING btree (id);

CREATE UNIQUE INDEX documents_storage_object_id_key ON public.documents USING btree (storage_object_id);

alter table "public"."document_sections" add constraint "document_sections_pkey" PRIMARY KEY using index "document_sections_pkey";

alter table "public"."documents" add constraint "documents_pkey" PRIMARY KEY using index "documents_pkey";

alter table "public"."document_sections" add constraint "document_sections_document_id_fkey" FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE CASCADE not valid;

alter table "public"."document_sections" validate constraint "document_sections_document_id_fkey";

alter table "public"."document_sections" add constraint "document_sections_document_id_page_number_section_index_key" UNIQUE using index "document_sections_document_id_page_number_section_index_key";

alter table "public"."document_sections" add constraint "document_sections_type_check" CHECK ((type = ANY (ARRAY['title'::text, 'text'::text, 'table'::text, 'figure'::text, 'formula'::text, 'list'::text, 'header'::text, 'footer'::text, 'other'::text]))) not valid;

alter table "public"."document_sections" validate constraint "document_sections_type_check";

alter table "public"."documents" add constraint "documents_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed'::text]))) not valid;

alter table "public"."documents" validate constraint "documents_status_check";

alter table "public"."documents" add constraint "documents_storage_object_id_fkey" FOREIGN KEY (storage_object_id) REFERENCES storage.objects(id) ON DELETE CASCADE not valid;

alter table "public"."documents" validate constraint "documents_storage_object_id_fkey";

alter table "public"."documents" add constraint "documents_storage_object_id_key" UNIQUE using index "documents_storage_object_id_key";

alter table "public"."documents" add constraint "documents_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."documents" validate constraint "documents_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_document_upload()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'storage', 'pgmq'
AS $function$
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


  create policy "users read own documents"
  on "public"."documents"
  as permissive
  for select
  to public
using ((user_id = auth.uid()));



  create policy "users read own files"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));



  create policy "users upload to own folder"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'documents'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));


CREATE TRIGGER on_document_uploaded AFTER INSERT ON storage.objects FOR EACH ROW WHEN ((new.bucket_id = 'documents'::text)) EXECUTE FUNCTION public.handle_document_upload();


