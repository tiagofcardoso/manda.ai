-- ============================================================
-- MANDA.AI — SECURITY UPDATE: Ativar RLS na tabela deliveries
-- Aplica em: Supabase SQL Editor
-- Data: 2026-04-01
-- ============================================================
-- ROLLBACK: ver docs/supabase_rollback.sql
-- ============================================================

-- PASSO 1: Ativar Row Level Security
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

-- PASSO 2: Admins do estabelecimento veem todas as entregas
CREATE POLICY "deliveries_admin_read"
ON public.deliveries FOR SELECT
TO authenticated
USING (
  get_my_role() = ANY (ARRAY['admin'::text, 'super_admin'::text, 'manager'::text])
);

-- PASSO 3: Drivers veem apenas as suas próprias entregas
CREATE POLICY "deliveries_driver_read"
ON public.deliveries FOR SELECT
TO authenticated
USING (
  driver_id = auth.uid()
);

-- PASSO 4: Drivers atualizam apenas as suas próprias entregas (GPS location)
CREATE POLICY "deliveries_driver_update"
ON public.deliveries FOR UPDATE
TO authenticated
USING (driver_id = auth.uid())
WITH CHECK (driver_id = auth.uid());

-- PASSO 5: Admins e o backend (service role) podem criar entregas
-- Nota: o backend Python usa SERVICE_ROLE_KEY que bypassa RLS,
-- portanto apenas precisamos de cobrir inserções feitas pelo Flutter Admin.
CREATE POLICY "deliveries_admin_insert"
ON public.deliveries FOR INSERT
TO authenticated
WITH CHECK (
  get_my_role() = ANY (ARRAY['admin'::text, 'super_admin'::text])
);

-- VERIFICAÇÃO: Confirmar que as policies foram criadas
SELECT policyname, cmd, roles::text
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'deliveries'
ORDER BY policyname;
