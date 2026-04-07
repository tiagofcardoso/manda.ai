-- ============================================================
-- MANDA.AI — Fix: Permitir leitura de pedidos de guests (mesa)
-- Data: 2026-04-06
-- Problema: Pedidos de mesa criados sem sessão (user_id IS NULL)
--           não são legíveis pela policy "orders_read_own"
--           porque NULL = NULL é FALSE no PostgreSQL RLS.
-- ============================================================
-- ROLLBACK: ver secção comentada no final
-- ============================================================

BEGIN;

-- Permite que utilizadores anónimos leiam pedidos de mesa
-- (pedidos criados pelo backend sem user_id)
-- SEGURO: UUIDs são de 128 bits — praticamente impossível de adivinhar
CREATE POLICY "orders_read_guest_table"
ON public.orders FOR SELECT
TO anon
USING (
  user_id IS NULL
  AND table_id IS NOT NULL  -- só pedidos de mesa (não delivery)
);

-- Permite que utilizadores anónimos leiam os itens desses pedidos
CREATE POLICY "order_items_read_guest_table"
ON public.order_items FOR SELECT
TO anon
USING (
  EXISTS (
    SELECT 1 FROM public.orders
    WHERE orders.id = order_items.order_id
    AND orders.user_id IS NULL
    AND orders.table_id IS NOT NULL
  )
);

COMMIT;

-- VERIFICAÇÃO
SELECT policyname, cmd, roles::text
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('orders', 'order_items')
  AND policyname LIKE '%guest%'
ORDER BY tablename, policyname;

-- ============================================================
-- ROLLBACK
-- ============================================================
/*
DROP POLICY IF EXISTS "orders_read_guest_table" ON public.orders;
DROP POLICY IF EXISTS "order_items_read_guest_table" ON public.order_items;
*/
