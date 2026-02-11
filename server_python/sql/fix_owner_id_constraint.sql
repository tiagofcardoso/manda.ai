-- =============================================================================
-- FIX ESTABLISHMENTS: Remove owner_id NOT NULL constraint
-- =============================================================================

-- In a SaaS model, super_admin creates establishments without being the owner
-- So owner_id should be nullable

ALTER TABLE public.establishments 
ALTER COLUMN owner_id DROP NOT NULL;

-- Verify
SELECT id, name, slug, type, owner_id, is_active
FROM public.establishments;
