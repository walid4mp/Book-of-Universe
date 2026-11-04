-- Kawn Library initial schema (apply to a NEW/test Supabase project first).
-- Reviewer/admin assignments must be managed by trusted server-side tooling.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  preferred_language text not null default 'ar' check (preferred_language in ('ar','fr','en')),
  bio text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(title) between 1 and 180),
  description text not null default '',
  language text not null check (language in ('ar','fr','en')),
  category text not null default 'other',
  cover_path text,
  publication_status text not null default 'draft'
    check (publication_status in ('draft','in_review','changes_requested','rejected','published','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.book_chapters (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books(id) on delete cascade,
  chapter_number integer not null check (chapter_number > 0),
  title text not null default '',
  body text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(book_id, chapter_number)
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'submitted'
    check (status in ('submitted','assigned','in_review','changes_requested','approved','rejected','withdrawn')),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.review_assignments (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete cascade,
  review_type text not null check (review_type in ('proofreading','literary_critique','editing','rights_check')),
  assignment_status text not null default 'assigned'
    check (assignment_status in ('assigned','in_progress','completed','cancelled')),
  assigned_at timestamptz not null default now(),
  unique(submission_id, reviewer_id, review_type)
);

create table if not exists public.review_reports (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.review_assignments(id) on delete cascade,
  summary text not null default '',
  suggestions jsonb not null default '[]'::jsonb,
  score integer check (score between 0 and 100),
  created_at timestamptz not null default now()
);

create table if not exists public.editorial_decisions (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id) on delete cascade,
  decided_by uuid not null references auth.users(id),
  decision text not null check (decision in ('approved','rejected','changes_requested')),
  reason text not null default '',
  created_at timestamptz not null default now()
);

-- Enable RLS everywhere in the exposed schema.
alter table public.profiles enable row level security;
alter table public.books enable row level security;
alter table public.book_chapters enable row level security;
alter table public.submissions enable row level security;
alter table public.review_assignments enable row level security;
alter table public.review_reports enable row level security;
alter table public.editorial_decisions enable row level security;

-- Profiles: users can read public profile fields and update only their own row.
drop policy if exists "profiles are readable" on public.profiles;
create policy "profiles are readable" on public.profiles for select to authenticated using (true);
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile" on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
drop policy if exists "users insert own profile" on public.profiles;
create policy "users insert own profile" on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

-- Authors may manage their own unpublished books. Published books are readable by signed-in users.
drop policy if exists "published books readable" on public.books;
create policy "published books readable" on public.books for select to authenticated
  using (publication_status = 'published' or author_id = (select auth.uid()));
drop policy if exists "authors create books" on public.books;
create policy "authors create books" on public.books for insert to authenticated
  with check (author_id = (select auth.uid()) and publication_status = 'draft');
drop policy if exists "authors update own draft books" on public.books;
create policy "authors update own draft books" on public.books for update to authenticated
  using (author_id = (select auth.uid()) and publication_status in ('draft','changes_requested'))
  with check (author_id = (select auth.uid()) and publication_status in ('draft','changes_requested'));

-- Chapter access follows book ownership or published status.
drop policy if exists "chapters readable with book access" on public.book_chapters;
create policy "chapters readable with book access" on public.book_chapters for select to authenticated
  using (exists (select 1 from public.books b where b.id = book_id and (b.publication_status = 'published' or b.author_id = (select auth.uid()))));
drop policy if exists "authors manage chapters" on public.book_chapters;
create policy "authors manage chapters" on public.book_chapters for all to authenticated
  using (exists (select 1 from public.books b where b.id = book_id and b.author_id = (select auth.uid()) and b.publication_status in ('draft','changes_requested')))
  with check (exists (select 1 from public.books b where b.id = book_id and b.author_id = (select auth.uid()) and b.publication_status in ('draft','changes_requested')));

-- Submission and committee tables intentionally have no client policies yet.
-- Implement reviewer access only after adding a server-managed role/assignment authorization model.
-- This fail-closed default prevents authors from reading internal committee reports or forging decisions.

revoke all on public.review_assignments, public.review_reports, public.editorial_decisions from anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.books to authenticated;
grant select, insert, update, delete on public.book_chapters to authenticated;
grant select, insert on public.submissions to authenticated;

create index if not exists books_published_created_idx on public.books (created_at desc) where publication_status = 'published';
create index if not exists books_author_idx on public.books (author_id);
create index if not exists chapters_book_number_idx on public.book_chapters (book_id, chapter_number);
create index if not exists submissions_author_idx on public.submissions (author_id, submitted_at desc);

-- Auth/profile role hardening and committee access model.
-- Signup may request only reader/writer. Committee/admin roles are granted by trusted admins only.
alter table public.profiles add column if not exists role text not null default 'reader'
  check (role in ('reader','writer','proofreader','critic','editor','committee_chair','admin'));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested text;
begin
  requested := coalesce(new.raw_user_meta_data ->> 'requested_role', 'reader');
  if requested not in ('reader','writer') then requested := 'reader'; end if;
  insert into public.profiles (id, display_name, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name',''), requested)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_kawn on auth.users;
create trigger on_auth_user_created_kawn
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Prevent clients from changing role or identity columns. Grant only safe profile fields.
revoke update on public.profiles from authenticated;
grant update (display_name, preferred_language, bio, updated_at) on public.profiles to authenticated;

create table if not exists public.role_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  requested_role text not null check (requested_role in ('proofreader','critic','editor','committee_chair')),
  message text not null default '',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
alter table public.role_requests enable row level security;
revoke all on public.role_requests from anon, authenticated;
grant select, insert on public.role_requests to authenticated;
drop policy if exists "users view own role requests" on public.role_requests;
create policy "users view own role requests" on public.role_requests for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "users submit own committee request" on public.role_requests;
create policy "users submit own committee request" on public.role_requests for insert to authenticated with check (user_id = (select auth.uid()) and status = 'pending');

-- A writer role is required to create a manuscript. Role itself cannot be self-assigned.
drop policy if exists "authors create books" on public.books;
create policy "authors create books" on public.books for insert to authenticated
  with check (author_id = (select auth.uid()) and publication_status = 'draft'
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('writer','admin')));

-- Submission creation is restricted to the owner of a writer's book.
drop policy if exists "authors submit own books" on public.submissions;
create policy "authors submit own books" on public.submissions for insert to authenticated
  with check (author_id = (select auth.uid()) and status = 'submitted'
    and exists (select 1 from public.books b where b.id = book_id and b.author_id = (select auth.uid()) and b.publication_status in ('draft','changes_requested'))
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('writer','admin')));

drop policy if exists "authors read own submissions" on public.submissions;
create policy "authors read own submissions" on public.submissions for select to authenticated
  using (author_id = (select auth.uid()));

-- Committee members may read only assignments addressed to them.
drop policy if exists "reviewers read assigned reviews" on public.review_assignments;
create policy "reviewers read assigned reviews" on public.review_assignments for select to authenticated
  using (reviewer_id = (select auth.uid()) and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('proofreader','critic','editor','committee_chair','admin')));

drop policy if exists "reviewers read assigned reports" on public.review_reports;
create policy "reviewers read assigned reports" on public.review_reports for select to authenticated
  using (exists (select 1 from public.review_assignments a where a.id = assignment_id and a.reviewer_id = (select auth.uid())));
drop policy if exists "reviewers create assigned reports" on public.review_reports;
create policy "reviewers create assigned reports" on public.review_reports for insert to authenticated
  with check (exists (select 1 from public.review_assignments a where a.id = assignment_id and a.reviewer_id = (select auth.uid()) and a.assignment_status in ('assigned','in_progress')));

-- Committee decisions are limited to chair/admin roles; authors cannot forge publication decisions.
drop policy if exists "chairs read editorial decisions" on public.editorial_decisions;
create policy "chairs read editorial decisions" on public.editorial_decisions for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('committee_chair','admin')));
drop policy if exists "chairs create editorial decisions" on public.editorial_decisions;
create policy "chairs create editorial decisions" on public.editorial_decisions for insert to authenticated
  with check (decided_by = (select auth.uid()) and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role in ('committee_chair','admin')));

-- Admin role grants are performed only by trusted SQL/dashboard/service-side operations.

-- Profiles are created by the trusted auth trigger; clients cannot insert or change role.
revoke insert, update on public.profiles from authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, preferred_language, bio, updated_at) on public.profiles to authenticated;

-- Explicit table privileges for RLS-governed committee workflows.
grant select on public.review_assignments to authenticated;
grant select, insert on public.review_reports to authenticated;
grant select, insert on public.editorial_decisions to authenticated;
grant select on public.submissions to authenticated;
grant select on public.books to authenticated;
grant select on public.book_chapters to authenticated;

drop policy if exists "reviewers read assigned submissions" on public.submissions;
create policy "reviewers read assigned submissions" on public.submissions for select to authenticated
  using (exists (select 1 from public.review_assignments a where a.submission_id = id and a.reviewer_id = (select auth.uid())));

drop policy if exists "reviewers read assigned manuscripts" on public.books;
create policy "reviewers read assigned manuscripts" on public.books for select to authenticated
  using (exists (select 1 from public.submissions s join public.review_assignments a on a.submission_id = s.id
    where s.book_id = books.id and a.reviewer_id = (select auth.uid())));

drop policy if exists "reviewers read assigned chapters" on public.book_chapters;
create policy "reviewers read assigned chapters" on public.book_chapters for select to authenticated
  using (exists (select 1 from public.submissions s join public.review_assignments a on a.submission_id = s.id
    where s.book_id = book_chapters.book_id and a.reviewer_id = (select auth.uid())));
