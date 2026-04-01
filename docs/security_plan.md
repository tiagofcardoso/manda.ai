# Plano de Segurança Manda.AI — Estado Final

**Última revisão:** 2026-04-01 | **Status:** ✅ Totalmente resolvido

---

## Resumo Executivo

Após análise completa do código Flutter e das regras Supabase, foram identificados **1 problema crítico** e **2 melhorias opcionais**. O crítico foi resolvido. As melhorias são de baixo risco e não urgentes.

---

## ✅ O Que Foi Corrigido

### 1. RLS ativado na tabela `deliveries` — CRÍTICO → RESOLVIDO

A tabela `deliveries` estava sem Row Level Security, exposta publicamente. Foram criadas 4 políticas:

| Policy | Acção | Quem |
|---|---|---|
| `deliveries_admin_read` | SELECT | Admins/managers do estabelecimento |
| `deliveries_driver_read` | SELECT | Driver vê apenas as suas próprias |
| `deliveries_driver_update` | UPDATE | Driver actualiza apenas as suas |
| `deliveries_admin_insert` | INSERT | Admins podem criar entregas |

Script: `docs/supabase_security_update.sql`

### 2. Credenciais Flutter migradas para `dart-define` — ALTO → RESOLVIDO

As credenciais hardcoded em `main.dart` foram substituídas por:

```dart
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://jpysitnnnopomrgjbaxq.supabase.co',
);
const supabaseKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_...',
);
```

> [!NOTE]
> A `ANON_KEY` (publishable) é tecnicamente pública por design do Supabase — a segurança real está no RLS. A `SERVICE_ROLE_KEY` está apenas no servidor Python e nunca toca no Flutter. ✅

---

## ✅ O Que Já Estava Bem

| Tabela | RLS | Notas |
|---|---|---|
| `categories` | ✅ | Leitura pública + escrita restrita a admins |
| `establishments` | ✅ | Leitura pública + escrita restrita |
| `order_items` | ✅ | Criação ligada ao user_id do pedido |
| `orders` | ✅ | Clientes vêem os seus; Admins vêem do estabelecimento |
| `products` | ✅ | Leitura pública + gestão restrita a admins |
| `profiles` | ✅ | Cada utilizador apenas vê e edita o seu |
| `tables` | ✅ | Leitura pública (necessária para QR scan) |

**Funções SQL** (todas `SECURITY DEFINER` ✅):
- `get_my_role()` — usada pelo `auth_service.dart` via RPC, nunca confia em cache local
- `get_my_establishment()` — idem
- `assign_establishment_admin()` — verifica permissão do requester antes de agir
- `handle_new_user()` — trigger seguro de criação de perfil

**Fluxo de pedidos dos guests**: Passa pelo **backend Python** (`SERVICE_ROLE_KEY`), não directamente pelo Supabase anon. O RLS nas `orders` não bloqueia este fluxo. ✅

---

## 🟡 Melhorias Opcionais (Baixo Risco, Não Urgentes)

### A. Policy `order_items_read` um pouco permissiva

A policy actual permite que qualquer utilizador autenticado leia `order_items` se o pedido pai existir. Não filtra por estabelecimento nem por dono do pedido.

**Risco real:** Baixo. Requer autenticação. Só é explorado se alguém souber um UUID de pedido alheio.

**Fix opcional** (só aplicar após testes no staging):
```sql
-- Substituir a policy existente por duas mais específicas
DROP POLICY "order_items_read" ON public.order_items;

-- Clientes lêem apenas itens dos seus próprios pedidos
CREATE POLICY "order_items_read_own"
ON public.order_items FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM orders
  WHERE orders.id = order_items.order_id
  AND orders.user_id = auth.uid()
));

-- Admins lêem itens de pedidos do seu estabelecimento
CREATE POLICY "order_items_admin_read"
ON public.order_items FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM orders
  WHERE orders.id = order_items.order_id
  AND (
    get_my_role() = ANY (ARRAY['admin','kitchen','manager','super_admin'])
    AND (orders.establishment_id = get_my_establishment() OR get_my_role() = 'super_admin')
  )
));
```

### B. Build CI/CD com `--dart-define` para remover os `defaultValue`

Quando tiveres um pipeline de CI/CD (GitHub Actions, etc.), os builds de produção devem injectar as variáveis sem `defaultValue`, para que um build feito sem as variáveis falhe explicitamente em vez de usar os defaults.

---

## 📁 Ficheiros de Backup e Rollback

| Ficheiro | Conteúdo |
|---|---|
| `docs/supabase_policies_backup.sql` | Todas as policies antes das mudanças |
| `docs/supabase_functions_backup.sql` | Todas as funções SQL |
| `docs/supabase_rollback.sql` | Script para desfazer as mudanças de segurança |
| `docs/supabase_security_update.sql` | Script aplicado na sessão de hoje |

---

## Verificação Final

- [x] `deliveries` — RLS ativado, 4 policies criadas e confirmadas
- [x] `main.dart` — credenciais migradas para `dart-define`
- [x] Git commit feito com todos os ficheiros de backup
- [x] Rollback preparado e testável
- [x] `order_items_read` melhorado — policy genérica substituída por `order_items_read_own` + `order_items_admin_read`
- [ ] (Futuro) CI/CD com `--dart-define` sem `defaultValue` quando tiveres pipeline automatizado
