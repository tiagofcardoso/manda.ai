# Arquitetura Explicada

Aqui está o detalhamento de como os dados estão fluindo entre o App, o Backend Python e o Supabase (Banco de Dados).

## 1. Criar/Atualizar Admin (Salvar)
**Fluxo:** `Flutter App` -> `Python Backend` -> `Supabase Auth & DB`

1.  **Flutter App:**
    *   Chama `POST http://localhost:8000/admin/create-establishment-admin`.
    *   Envia `email`, `establishment_id`, `full_name` e `phone_number`.

2.  **Python Backend (`main.py`):**
    *   **Auth Check:** Usa `supabase_admin.auth` para ver se o usuário existe.
    *   **User Creation:** Se não existir, cria o usuário em `auth.users` com senha "Manda2024!".
    *   **Role Assignment:** Chama a função PostgreSQL (RPC) `assign_establishment_admin` para setar o user como admin e vincular à loja.
    *   **Profile Update:** Finalmente, faz um update direto na tabela `public.profiles` para salvar `full_name` e `phone_number`.
        ```python
        supabase_admin.from_('profiles').update(profile_update).eq('id', user_id).execute()
        ```

## 2. Buscar Dados do Admin (Email)
**Fluxo:** `Flutter App` -> `Python Backend` -> `Supabase Auth & DB`

1.  **Flutter App:**
    *   Chama `GET http://localhost:8000/admin/establishment-admin/{id}` ao abrir a loja.

2.  **Python Backend (`main.py`):**
    *   **Find Profile:** Busca na `public.profiles` quem é o admin vinculado à loja.
    *   **Get Email:** Usa o `supabase_admin.auth.admin.get_user_by_id(user_id)` para pegar o email (que fica na tabela separada e segura `auth.users`, não na `public.profiles`).

## 3. Deletar Loja (Frontend)
**Fluxo:** `Flutter App` -> `Supabase DB`

1.  **Flutter App (`super_admin_dashboard_screen.dart`):**
    *   **Desvincular Usuários:** Primeiro, atualiza todos os perfis dessa loja para `establishment_id = NULL`.
        ```dart
        await _supabase.from('profiles').update({'establishment_id': null}).eq('establishment_id', id);
        ```
    *   **Deletar Loja:** Com os usuários "soltos", manda deletar a loja.
        ```dart
        await _supabase.from('establishments').delete().eq('id', id);
        ```
    *   *Nota: Isso é feito diretamente via Supabase Flutter Client, garantindo que respeita as chaves estrangeiras do banco.*

Isso explica por que você talvez não tenha visto logs de endpoint na deleção (pois foi direto no banco/Supabase) ou por que o email precisou de uma rota backend específica.
