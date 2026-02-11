-- ============================================================================
-- SQL DE DIAGNÓSTICO
-- Ajuda a identificar se as tabelas e funções foram criadas corretamente
-- ============================================================================

-- 1. Listar colunas da tabela PROFILES (para verificar 'must_change_password')
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- 2. Verificar se a função 'assign_establishment_admin' existe e seus argumentos
SELECT routine_name, routine_type, security_type
FROM information_schema.routines
WHERE routine_name = 'assign_establishment_admin';

-- 3. Verificar triggers na tabela PROFILES
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'profiles';

-- 4. Verificar se a constraint 'profiles_role_check' está correta (se estamos usando TEXT ou ENUM)
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.profiles'::regclass;

-- 5. Listar usuários da tabela auth.users (APENAS 5 PARA TESTE) - Cuidado com dados sensíveis
SELECT id, email, created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;

-- ============================================================================
