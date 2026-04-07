-- ============================================================
-- MANDA.AI — Fix: Drivers conseguem ver a pool de entregas abertas
-- Data: 2026-04-06
-- Problema: A policy "deliveries_driver_read" só permite
--           driver_id = auth.uid(), mas entregas abertas têm
--           driver_id = NULL. Logo drivers não vêem a pool.
-- ============================================================
-- ROLLBACK: ver secção comentada no final
-- ============================================================

BEGIN;

-- Permite que qualquer driver autenticado veja as entregas abertas (pool)
-- SEGURO: só mostra deliveries com status='open', não expõe as de outros drivers
CREATE POLICY "deliveries_driver_see_pool"
ON public.deliveries FOR SELECT
TO authenticated
USING (
  status = 'open'
  AND get_my_role() = 'driver'
);

COMMIT;

-- VERIFICAÇÃO: confirmar todas as policies em deliveries
SELECT policyname, cmd, roles::text, qual
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'deliveries'
ORDER BY policyname;

-- ============================================================
-- ROLLBACK
-- ============================================================
/*
DROP POLICY IF EXISTS "deliveries_driver_see_pool" ON public.deliveries;
*/
