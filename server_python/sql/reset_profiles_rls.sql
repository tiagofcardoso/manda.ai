-- =============================================================================
-- RESET COMPLETO: PROFILES RLS
-- =============================================================================

-- 1. Temporariamente desabilitar RLS
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 2. Remover TODAS as políticas existentes
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Enable read for users" ON public.profiles;
DROP POLICY IF EXISTS "Enable update for users" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;

-- 3. Re-habilitar RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Criar APENAS a política básica (SEM recursão)
-- Usuários podem ver apenas seu próprio perfil
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Usuários podem atualizar apenas seu próprio perfil  
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 5. Verificar políticas
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'profiles';
