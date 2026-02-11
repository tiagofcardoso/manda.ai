-- ============================================================================
-- GESTÃO DE USUÁRIOS E PERMISSÕES
-- Use estes scripts para gerenciar acessos manualmente
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. VINCULAR UM USUÁRIO A UM ESTABELECIMENTO (Tornar Dono/Admin)
-- ----------------------------------------------------------------------------
-- Substitua 'EMAIL_DO_USUARIO' e 'NOME_DO_ESTABELECIMENTO' pelos valores reais

UPDATE public.profiles
SET 
    -- Busca o ID do estabelecimento pelo nome (pega o primeiro encontrado)
    establishment_id = (SELECT id FROM public.establishments WHERE name ILIKE '%Manda.AI Burger%' LIMIT 1),
    
    -- Define o papel como 'admin'
    role = 'admin'

WHERE id = (
    -- Busca o ID do usuário pelo email
    SELECT id FROM auth.users WHERE email = 'admin@manda.ai'
);


-- ----------------------------------------------------------------------------
-- 2. TORNAR UM USUÁRIO SUPER ADMIN (Acesso total a tudo)
-- ----------------------------------------------------------------------------
/*
UPDATE public.profiles
SET role = 'super_admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'seu_email@exemplo.com');
*/


-- ----------------------------------------------------------------------------
-- 3. REMOVER ACESSO DE UM USUÁRIO (Voltar para cliente)
-- ----------------------------------------------------------------------------
/*
UPDATE public.profiles
SET 
    establishment_id = NULL,
    role = 'customer'
WHERE id = (SELECT id FROM auth.users WHERE email = 'funcionario_demitido@exemplo.com');
*/


-- ----------------------------------------------------------------------------
-- 4. CONSULTAR QUEM É ADMIN DE QUAL ESTABELECIMENTO
-- ----------------------------------------------------------------------------
/*
SELECT 
    u.email, 
    p.role, 
    e.name as establishment_name
FROM public.profiles p
JOIN auth.users u ON p.id = u.id
LEFT JOIN public.establishments e ON p.establishment_id = e.id
WHERE p.role IN ('admin', 'super_admin');
*/
