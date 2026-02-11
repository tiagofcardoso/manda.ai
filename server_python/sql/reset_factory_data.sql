-- ============================================================================
-- SQL DE RESET TOTAL (MANTENDO APENAS SUPER ADMIN)
-- ============================================================================
-- ATENÇÃO: Este script apaga DADOS. Execute com cuidado.
-- ============================================================================

-- 1. Desvincular todos os usuários de seus estabelecimentos.
-- Isso evita o erro "violates foreign key constraint" ao tentar apagar as lojas.
UPDATE public.profiles
SET establishment_id = NULL
WHERE role != 'super_admin';

-- 2. Apagar todos os estabelecimentos.
-- Agora que ninguém está vinculado, podemos apagar sem erro.
DELETE FROM public.establishments;

-- 3. (Opcional) Apagar os perfis que não são Super Admin.
DELETE FROM public.profiles
WHERE role != 'super_admin';

-- ============================================================================
-- DIAGNÓSTICO PÓS-RESET
-- ============================================================================

-- Verificar quem sobrou (deve ser apenas o Super Admin)
SELECT * FROM public.profiles;

-- Verificar se as lojas foram apagadas
SELECT * FROM public.establishments;

-- ============================================================================
-- NOTA SOBRE O ERRO ANTERIOR:
-- O erro "violates foreign key constraint" aconteceu porque a tabela 'profiles'
-- tem uma coluna 'establishment_id' que aponta para a loja. O banco protege
-- a loja de ser apagada enquanto houver alguém apontando para ela.
-- O nosso código no Frontend tentou remover esse link, mas provavelmente foi
-- bloqueado pelas regras de segurança (RLS - Row Level Security) do Supabase,
-- pois um usuário (mesmo admin) geralmente não tem permissão para editar o 
-- perfil de outros usuários diretamente pelo Front-end.
-- ============================================================================
