# Manual de Gestão de Usuários e Permissões

Este guia descreve como gerenciar manualmente o acesso de donos e funcionários aos estabelecimentos no Manda.AI.

## Fluxo Atual (Sem Painel de Gestão de Equipe)

Atualmente, não existe uma tela no aplicativo para adicionar membros à equipe. O processo é feito em duas etapas:
1.  **O Usuário cria a conta:** O dono/funcionário baixa o app e faz o cadastro normal (Sign Up).
2.  **O Super Admin libera o acesso:** Você roda um script no banco de dados para vincular esse usuário à loja correta.

---

## Passo a Passo: Definir um Dono de Estabelecimento

### 1. Peça para o dono criar uma conta
Instrua o dono da farmácia (ou qualquer estabelecimento) a:
1.  Baixar o App ou acessar a versão Web.
2.  Clicar em **Criar Conta**.
3.  Preencher nome, email e senha.
4.  Confirmar o e-mail (se necessário).
5.  **IMPORTANTE:** Ele deve te informar qual **E-mail** ele utilizou no cadastro.

### 2. Rodar o Script de Vinculação (Supabase)
Com o e-mail do dono e o nome da farmácia em mãos:

1.  Acesse o **Supabase Dashboard** > **SQL Editor**.
2.  Cole e execute o seguinte comando (substituindo os dados):

```sql
-- ATRIBUIR ADMINISTRAÇÃO DE UMA LOJA
UPDATE public.profiles
SET 
  -- Substitua 'NOME_DA_LOJA' pelo nome exato (ou parte dele)
  establishment_id = (SELECT id FROM public.establishments WHERE name ILIKE '%NOME_DA_LOJA%' LIMIT 1),
  role = 'admin'
WHERE id = (
  -- Substitua 'EMAIL_DO_DONO' pelo e-mail exato
  SELECT id FROM auth.users WHERE email = 'EMAIL_DO_DONO'
);
```

**Exemplo Prático:**
Se você criou a "Farmácia da Vila" e o dono é "joao@farmacia.com":

```sql
UPDATE public.profiles
SET 
  establishment_id = (SELECT id FROM public.establishments WHERE name ILIKE '%Farmácia da Vila%' LIMIT 1),
  role = 'admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'joao@farmacia.com');
```

---

## O que acontece depois?

Assim que você rodar o script e aparecer `UPDATE 1` (sucesso):
1.  O usuário "joao@farmacia.com" passa a ser **ADMIN** da "Farmácia da Vila".
2.  Na próxima vez que ele abrir o app (talvez precise fazer Logout e Login novamente), ele verá o painel administrativo da farmácia dele.
3.  Ele poderá:
    *   Editar dados da loja (nome, logo, moeda).
    *   Criar/Editar produtos.
    *   Ver pedidos daquela loja.
    *   Ver entregas.

---

## Dúvidas Comuns

**E se eu quiser dar acesso total (Super Admin)?**
Rode:
```sql
UPDATE public.profiles
SET role = 'super_admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@manda.ai');
```

**Como remover um acesso?**
Para "demitir" um usuário ou remover acesso de admin:
```sql
UPDATE public.profiles
SET establishment_id = NULL, role = 'customer'
WHERE id = (SELECT id FROM auth.users WHERE email = 'ex_funcionario@manda.ai');
```
