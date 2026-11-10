-- Run in the SQL editor of project mrbrromdzjecidqgycux, after reviewing
-- existing data and policies. This preserves existing rows and tables.
-- It replaces the broad policy proposed by the original HTML application.

BEGIN;

CREATE TABLE IF NOT EXISTS public.aitu_student_profiles (
  student_id text PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  app_state jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.aitu_student_profiles
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Associate legacy email-keyed rows with the matching Supabase Auth account.
UPDATE public.aitu_student_profiles AS p
SET user_id = u.id
FROM auth.users AS u
WHERE p.user_id IS NULL
  AND lower(p.student_id) = lower(u.email);

ALTER TABLE public.aitu_student_profiles ENABLE ROW LEVEL SECURITY;

-- Original app setup granted every anonymous visitor full access.
DROP POLICY IF EXISTS "Allow public read/write for student profiles"
  ON public.aitu_student_profiles;
REVOKE ALL ON TABLE public.aitu_student_profiles FROM anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.aitu_student_profiles TO authenticated;

DROP POLICY IF EXISTS "Students select own profile" ON public.aitu_student_profiles;
DROP POLICY IF EXISTS "Students insert own profile" ON public.aitu_student_profiles;
DROP POLICY IF EXISTS "Students update own profile" ON public.aitu_student_profiles;

CREATE POLICY "Students select own profile"
ON public.aitu_student_profiles FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Students insert own profile"
ON public.aitu_student_profiles FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Students update own profile"
ON public.aitu_student_profiles FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

COMMIT;

-- Inspect the result. Any OTHER permissive policy on this table must be
-- reviewed because PostgreSQL combines permissive policies with OR.
SELECT policyname, cmd, roles, qual, with_check
FROM pg_catalog.pg_policies
WHERE schemaname = 'public' AND tablename = 'aitu_student_profiles'
ORDER BY policyname;
