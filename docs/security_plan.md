# Plano de Segurança Manda.AI — Revisão Técnica Completa

> Este documento foi revisado e ampliado com base na análise direta do código-fonte em Abril/2026.

---

## Diagnóstico: O Que Já Está Bom ✅

- **`getUserRole()` usa `get_my_role` RPC** — correto. O app não confia no cache local; busca o papel do servidor via função SQL `SECURITY DEFINER`. Isso é a arquitectura certa.
- **JWT é enviado em cada request HTTP** — `session.accessToken` é passado no header `Authorization: Bearer ...` em todos os calls ao backend Python.
- **`.env` NÃO está nos `assets` do `pubspec.yaml`** — já foi removido. Não há vazamento via assets.

---

## Vulnerabilidades Identificadas

### 🔴 CRÍTICO — RLS Desativado na tabela `deliveries`

O **Security Advisor do Supabase** reportou que `public.deliveries` está exposta publicamente — qualquer pessoa com a URL do projeto pode ler, editar e apagar localidades de entregadores em tempo real.

**Solução:** Ativar RLS + criar políticas na tabela `deliveries`.

---

### 🟠 ALTO — Credenciais hardcoded em `main.dart`

```dart
// lib/main.dart (linha 26-27) — PROBLEMA ATUAL
const supabaseUrl = 'https://jpysitnnnopomrgjbaxq.supabase.co';
const supabaseKey = 'sb_publishable_2ydfHF0FqCYOr5ZQ5NZ4QQ_UUDvboCo';
```

A `PUBLISHABLE_KEY` (anon key) tecnicamente é segura de expor — o Supabase é desenhado assim. **O perigo real** é que o arquivo `.env` na raiz do projeto contém a `SUPABASE_SERVICE_ROLE_KEY` e a `SUPABASE_KEY` (secret key). Se esse arquivo for commitado acidentalmente para o Git, essas chaves dão **acesso total irrestrito** ao banco.

> [!CAUTION]
> O `.env` está no `.gitignore` ✅ — mas a `SUPABASE_SERVICE_ROLE_KEY` está lá. Nunca deixar essa chave entrar no Flutter. Ela só deve existir no `server_python`.

**Solução para o Flutter:** Usar `--dart-define` no build para injetar apenas a anon key de forma limpa.

---

### 🟡 MÉDIO — Outras tabelas sem RLS auditadas

As seguintes tabelas são usadas no app e precisam ter as RLS verificadas no painel Supabase:

| Tabela | Quem acessa | Risco se sem RLS |
|---|---|---|
| `orders` | Todos (guests, clients, admins) | Qualquer pessoa lê/altera pedidos de outros |
| `order_items` | Todos | Altera itens de pedidos alheios |
| `tables` | Guests (via QR scan) | Leitura de todas as mesas — baixo risco |
| `products` | Público (menu) | Leitura pública OK; escrita deve ser restrita |
| `categories` | Público (menu) | Leitura pública OK |
| `establishments` | Público (marketplace) | Leitura pública OK; escrita restrita |
| `profiles` | Usuário autenticado | Acesso cruzado entre perfis = crítico |
| `deliveries` | Drivers e admins | **⚠️ SEM RLS confirmado pelo Supabase** |

---

## Plano de Ação

### Fase 1 — RLS (Pode ser feito agora no painel Supabase)

Acede ao **Supabase Dashboard → Authentication → Policies** e verifica/cria:

#### Tabela `deliveries`
```sql
-- Habilitar RLS
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

-- Admins do estabelecimento podem ver tudo
CREATE POLICY "admins_see_all_deliveries"
ON public.deliveries FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('admin', 'super_admin')
  )
);

-- Drivers veem apenas suas próprias entregas
CREATE POLICY "driver_sees_own_deliveries"
ON public.deliveries FOR SELECT
USING (
  driver_id = auth.uid()
);

-- Drivers atualizam apenas suas próprias entregas
CREATE POLICY "driver_updates_own_deliveries"
ON public.deliveries FOR UPDATE
USING (driver_id = auth.uid());
```

#### Tabela `orders`
```sql
-- Clientes veem apenas seus próprios pedidos
CREATE POLICY "clients_see_own_orders"
ON public.orders FOR SELECT
USING (user_id = auth.uid());

-- Admins veem pedidos do seu estabelecimento
CREATE POLICY "admins_see_establishment_orders"
ON public.orders FOR SELECT
USING (
  establishment_id IN (
    SELECT establishment_id FROM public.profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'super_admin')
  )
);

-- Guests podem criar pedidos (sem login)
CREATE POLICY "guests_can_insert_orders"
ON public.orders FOR INSERT
WITH CHECK (true); -- Controlado pelo backend Python
```

#### Tabela `profiles`
```sql
-- Utilizador vê apenas o próprio perfil
CREATE POLICY "users_see_own_profile"
ON public.profiles FOR SELECT
USING (id = auth.uid());

-- Utilizador actualiza apenas o próprio perfil
CREATE POLICY "users_update_own_profile"
ON public.profiles FOR UPDATE
USING (id = auth.uid());
```

---

### Fase 2 — Credenciais Flutter (Dart)

**Substituir as constantes hardcoded** por `String.fromEnvironment`:

```dart
// lib/main.dart — VERSÃO SEGURA
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://jpysitnnnopomrgjbaxq.supabase.co',
);
const supabaseKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_2ydfHF0FqCYOr5ZQ5NZ4QQ_UUDvboCo',
);
```

Para builds de produção, injectar via CLI:
```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://jpysi... \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
```

> [!NOTE]
> O `defaultValue` garante que o app continua a funcionar em `flutter run` sem configuração adicional no dia-a-dia de desenvolvimento — mas numa build CI/CD os valores reais são injectados.

---

### Fase 3 — Exportar e Auditar Policies Existentes

Para auditar o que já existe no Supabase, correr este SQL no **SQL Editor** do Dashboard:

```sql
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

Partilha o output connosco para validação completa.

---

## Perguntas Abertas

1. **O `server_python` usa a `SERVICE_ROLE_KEY` diretamente?** Se sim, está correto — mas precisamos confirmar que o servidor Python nunca expõe essa chave em logs ou responses.
2. **Existe alguma integração de pagamento (Stripe/MB Way)?** Se sim, essas chaves também devem ser apenas no servidor Python, nunca no Flutter.
3. **A função SQL `get_my_role` já existe no Supabase?** (O `auth_service.dart` usa-a via `rpc('get_my_role')`)

---

## Verificação Final

- [ ] Testar RLS: tentar ler `/deliveries` sem autenticação via Postman → deve retornar `[]`
- [ ] Testar RLS: cliente autenticado tenta ler pedido de outro utilizador → deve retornar `[]`
- [ ] Confirmar que `flutter analyze` não reporta erros
- [ ] Confirmar que build web carrega corretamente com `--dart-define`
