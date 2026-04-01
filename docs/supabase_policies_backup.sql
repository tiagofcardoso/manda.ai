-- ============================================================
-- MANDA.AI — BACKUP COMPLETO DAS POLICIES RLS
-- Exportado em: 2026-04-01
-- Estado: 7/8 tabelas com RLS ativo. "deliveries" sem RLS.
-- ============================================================

-- === ESTADO RLS POR TABELA ===
-- categories     | RLS: true  | forced: false ✅
-- deliveries     | RLS: false | forced: false ❌ (CRÍTICO)
-- establishments | RLS: true  | forced: false ✅
-- order_items    | RLS: true  | forced: false ✅
-- orders         | RLS: true  | forced: false ✅
-- products       | RLS: true  | forced: false ✅
-- profiles       | RLS: true  | forced: false ✅
-- tables         | RLS: true  | forced: false ✅


-- === POLICIES EXISTENTES (para restaurar se necessário) ===

-- CATEGORIES
CREATE POLICY "categories_admin_all" ON public.categories AS PERMISSIVE FOR ALL TO authenticated
USING ((get_my_role() = ANY (ARRAY['admin'::text, 'super_admin'::text])) AND ((establishment_id = get_my_establishment()) OR (get_my_role() = 'super_admin'::text)));

CREATE POLICY "categories_read_public" ON public.categories AS PERMISSIVE FOR SELECT TO anon, authenticated
USING (true);

-- ESTABLISHMENTS
CREATE POLICY "establishments_admin_update" ON public.establishments AS PERMISSIVE FOR UPDATE TO authenticated
USING (((get_my_role() = 'admin'::text) AND (id = get_my_establishment())) OR (get_my_role() = 'super_admin'::text))
WITH CHECK (((get_my_role() = 'admin'::text) AND (id = get_my_establishment())) OR (get_my_role() = 'super_admin'::text));

CREATE POLICY "establishments_read_public" ON public.establishments AS PERMISSIVE FOR SELECT TO anon, authenticated
USING (true);

CREATE POLICY "establishments_super_admin_all" ON public.establishments AS PERMISSIVE FOR ALL TO authenticated
USING (get_my_role() = 'super_admin'::text);

-- ORDER_ITEMS
CREATE POLICY "order_items_create" ON public.order_items AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM orders WHERE (orders.id = order_items.order_id) AND (orders.user_id = auth.uid())));

CREATE POLICY "order_items_read" ON public.order_items AS PERMISSIVE FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM orders WHERE orders.id = order_items.order_id));

-- ORDERS
CREATE POLICY "orders_admin_read" ON public.orders AS PERMISSIVE FOR SELECT TO authenticated
USING ((get_my_role() = ANY (ARRAY['admin'::text, 'kitchen'::text, 'manager'::text, 'super_admin'::text])) AND ((establishment_id = get_my_establishment()) OR (get_my_role() = 'super_admin'::text)));

CREATE POLICY "orders_admin_update" ON public.orders AS PERMISSIVE FOR UPDATE TO authenticated
USING ((get_my_role() = ANY (ARRAY['admin'::text, 'kitchen'::text, 'manager'::text, 'super_admin'::text])) AND ((establishment_id = get_my_establishment()) OR (get_my_role() = 'super_admin'::text)));

CREATE POLICY "orders_create_own" ON public.orders AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY "orders_read_own" ON public.orders AS PERMISSIVE FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- PRODUCTS
CREATE POLICY "products_admin_all" ON public.products AS PERMISSIVE FOR ALL TO authenticated
USING ((get_my_role() = ANY (ARRAY['admin'::text, 'super_admin'::text])) AND ((establishment_id = get_my_establishment()) OR (get_my_role() = 'super_admin'::text)));

CREATE POLICY "products_read_public" ON public.products AS PERMISSIVE FOR SELECT TO anon, authenticated
USING (true);

-- PROFILES
CREATE POLICY "profiles_read_own" ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated
USING (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated
USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- TABLES
CREATE POLICY "tables_admin_all" ON public.tables AS PERMISSIVE FOR ALL TO authenticated
USING ((get_my_role() = ANY (ARRAY['admin'::text, 'super_admin'::text])) AND ((establishment_id = get_my_establishment()) OR (get_my_role() = 'super_admin'::text)));

CREATE POLICY "tables_read_public" ON public.tables AS PERMISSIVE FOR SELECT TO anon, authenticated
USING (true);
