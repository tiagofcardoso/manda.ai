-- ============================================================
-- MANDA.AI — SCRIPT DE BACKUP DAS POLICIES RLS ATUAIS
-- Executa este SQL no Supabase SQL Editor → guarda o resultado
-- ============================================================

-- 1. EXPORTAR TODAS AS POLICIES ATUAIS (copiar o output!)
SELECT
  'CREATE POLICY "' || policyname || '"' ||
  ' ON ' || schemaname || '.' || tablename ||
  ' AS ' || permissive ||
  ' FOR ' || cmd ||
  CASE WHEN roles != '{}'::name[] THEN ' TO ' || array_to_string(roles, ', ') ELSE '' END ||
  CASE WHEN qual IS NOT NULL THEN ' USING (' || qual || ')' ELSE '' END ||
  CASE WHEN with_check IS NOT NULL THEN ' WITH CHECK (' || with_check || ')' ELSE '' END ||
  ';' AS policy_definition
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;


-- 2. EXPORTAR STATUS RLS DE CADA TABELA
SELECT
  relname AS table_name,
  relrowsecurity AS rls_enabled,
  relforcerowsecurity AS rls_forced
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relkind = 'r'
ORDER BY relname;


-- 3. EXPORTAR FUNÇÕES CUSTOMIZADAS (ex: get_my_role)
SELECT
  routine_name,
  routine_type,
  security_type,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;
