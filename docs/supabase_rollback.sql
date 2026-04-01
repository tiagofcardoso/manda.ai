-- ============================================================
-- MANDA.AI — SCRIPT DE ROLLBACK DAS POLICIES RLS
-- Executa este SQL APENAS se precisares reverter as mudanças
-- ============================================================
-- ATENÇÃO: Este script REMOVE as policies que vamos criar.
-- Se já existiam policies antes, elas NÃO são afetadas.
-- ============================================================

-- ROLLBACK: Tabela deliveries
DROP POLICY IF EXISTS "admins_see_all_deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "driver_sees_own_deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "driver_updates_own_deliveries" ON public.deliveries;

-- ROLLBACK: Tabela orders
DROP POLICY IF EXISTS "clients_see_own_orders" ON public.orders;
DROP POLICY IF EXISTS "admins_see_establishment_orders" ON public.orders;
DROP POLICY IF EXISTS "guests_can_insert_orders" ON public.orders;

-- ROLLBACK: Tabela profiles
DROP POLICY IF EXISTS "users_see_own_profile" ON public.profiles;
DROP POLICY IF EXISTS "users_update_own_profile" ON public.profiles;

-- ROLLBACK: Desativar RLS nas tabelas que vamos ativar
-- (apenas se NÃO estavam ativas antes -- confirmar no backup_export.sql!)
-- ALTER TABLE public.deliveries DISABLE ROW LEVEL SECURITY;

-- Verificar estado final após rollback
SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename;
