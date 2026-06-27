-- Proposed audit table for VerifyAid face verification attempts.
-- Run this in Supabase SQL editor after confirming the profiles.tenant_id RLS
-- relationship matches your production schema.

create table if not exists public.face_verification_attempts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  program_id uuid not null,
  beneficiary_id uuid not null,
  distribution_event_id uuid null,
  verified_by uuid not null references auth.users(id),
  location_id uuid not null,
  registered_face_path text null,
  live_face_path text null,
  status text not null,
  match_score numeric null,
  threshold numeric null,
  quality_score numeric null,
  liveness_passed boolean null,
  algorithm text null,
  model_version text null,
  failure_reason text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.face_verification_attempts enable row level security;

drop policy if exists "Tenant users can read face verification attempts"
  on public.face_verification_attempts;

create policy "Tenant users can read face verification attempts"
  on public.face_verification_attempts
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and profiles.tenant_id = face_verification_attempts.tenant_id
    )
  );

drop policy if exists "Tenant users can insert face verification attempts"
  on public.face_verification_attempts;

create policy "Tenant users can insert face verification attempts"
  on public.face_verification_attempts
  for insert
  to authenticated
  with check (
    verified_by = auth.uid()
    and exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and profiles.tenant_id = face_verification_attempts.tenant_id
    )
  );

create index if not exists idx_face_verification_attempts_tenant_created
  on public.face_verification_attempts (tenant_id, created_at desc);

create index if not exists idx_face_verification_attempts_beneficiary
  on public.face_verification_attempts (beneficiary_id, created_at desc);
