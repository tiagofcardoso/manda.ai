-- ============================================================
-- MANDA.AI — Update: Reforçar policy order_items_read
-- Data: 2026-04-01
-- ROLLBACK: ver secção no final deste ficheiro
-- ============================================================
-- O QUE FAZ:
--   Remove a policy genérica que permite a qualquer utilizador
--   autenticado ler order_items de qualquer pedido.
--   Substitui por duas policies específicas:
--     1. Clientes lêem apenas itens dos seus próprios pedidos
--     2. Admins/kitchen/manager lêem itens do seu estabelecimento
-- ============================================================

BEGIN;

-- PASSO 1: Remover a policy permissiva existente
DROP POLICY IF EXISTS "order_items_read" ON public.order_items;

-- PASSO 2: Clientes lêem apenas itens dos seus próprios pedidos
CREATE POLICY "order_items_read_own"
ON public.order_items FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders
    WHERE orders.id = order_items.order_id
      AND orders.user_id = auth.uid()
  )
);

-- PASSO 3: Admins, kitchen e managers lêem itens do seu estabelecimento
CREATE POLICY "order_items_admin_read"
ON public.order_items FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders
    WHERE orders.id = order_items.order_id
      AND (
        -- É admin/kitchen/manager do estabelecimento correto
        (
          get_my_role() = ANY (ARRAY['admin'::text, 'kitchen'::text, 'manager'::text])
          AND orders.establishment_id = get_my_establishment()
        )
        OR
        -- Ou é super_admin (vê tudo)
        get_my_role() = 'super_admin'::text
      )
  )
);

COMMIT;

-- VERIFICAÇÃO: Confirmar as policies criadas
SELECT policyname, cmd, roles::text, qual
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'order_items'
ORDER BY policyname;

-- ============================================================
-- ROLLBACK (executar apenas se algo quebrar)
-- ============================================================
/*
BEGIN;

DROP POLICY IF EXISTS "order_items_read_own" ON public.order_items;
DROP POLICY IF EXISTS "order_items_admin_read" ON public.order_items;

CREATE POLICY "order_items_read"
ON public.order_items FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders
    WHERE orders.id = order_items.order_id
  )
);

COMMIT;
*/
