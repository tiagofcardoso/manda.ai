# Análise de Segurança de Ponta a Ponta: Manda.AI

Este plano detalha as ações técnicas para reforçar e certificar a segurança da aplicação Flutter e do backend associado (Supabase). O objetivo é garantir que não existam vetores de ataque expostos nem credenciais acessíveis no binário cliente.

> [!WARNING]
> Encontrei uma vulnerabilidade imediata: o arquivo `.env` está explicitamente mapeado no `pubspec.yaml` sob a pasta `assets` e as credenciais (`supabaseUrl`, `supabaseKey`) estão *hardcoded* (texto puro) no `main.dart`. Se você publicar o app na loja agora, qualquer pessoa pode extrair o binário (`.apk` ou `.js`) e ver/copiar essas chaves ou APIs de terceiros.

## Revisão Necessária (User Review Required)

Antes de prosseguirmos com as edições no código-fonte, preciso do seu de acordo sobre as seguintes frentes de atuação:

**1. Ocultação de Credenciais e Variáveis de Ambiente**
*   **Problema:** Atualmente, as variáveis estão fixas no arquivo `main.dart` e o arquivo `.env` está listado nos `assets/` do projeto (o que o transforma em um arquivo público legível quando o app é compilado).
*   **Solução:** Vamos remover a menção do `.env` nos `assets` do `pubspec.yaml` e atualizar o método de injeção de ambiente para compilação segura (`--dart-define` ou pacotes que ofuscam variáveis no Dart compilado, como `envied`).

**2. Revisão do Controle de Acesso e Perfil**
*   **Problema:** Precisamos nos certificar de que qualquer manipulação local dentro do app (alguém tentar hackear sua role localmente, alterando de `client` para `admin`) baterá na parede blindada do Supabase e terá o acesso negado.
*   **Solução:** Analisar as lógicas no Flutter (`auth_service.dart`) para garantir que os JWTs gerados estão sendo enviados corretamente.

**3. Revisão do Supabase / Row Level Security (RLS)**
*   **Problema:** O código do banco de dados (esquemas e SQL) **não** está arquivado dentro da pasta atual de desenvolvimento (`manda.ai`), o que significa que as Policies de segurança estão configuradas apenas via Painel na Nuvem.
*   **Ação Mútua:** Eu vou instruir você sobre como exportar suas *Policies SQL* atuais diretamente lá do painel Supabase > SQL Editor para eu analisá-las, pois se a RLS estiver falha, o app estará à mercê de injeções diretas.

**4. Refino de Lógicas do App e Dependências**
*   Estou terminando de executar um `flutter analyze` em segundo plano para varrer qualquer erro estático ou lógica obsoleta.
*   Faremos um escaneamento nas versões do seu `pubspec.yaml` para atualizar pacotes que tenham vulnerabilidades clássicas divulgadas em (CVE/OSV).

## Plano de Mudanças

> [!CAUTION]
> As ações abaixo envolvem quebra de código legado (`.env`), caso haja customizações prévias precisamos testar a injeção em Web/Mobile.

### Frontend Flutter (`app_flutter`)

#### [MODIFY] pubspec.yaml
- Remover `- lib/.env` da lista de `assets:` para evitar vazamento silencioso em *releases*.

#### [MODIFY] lib/main.dart
- Retirar as variáveis `supabaseUrl` e `supabaseKey` em texto puro ("hardcoded"). Substituir pelo chamado de `String.fromEnvironment('SUPABASE_KEY')` para injeção via comando CLI ou pacote OFUSCADO.

#### [MODIFY] lib/services/auth_service.dart
- Adicionar verificações contra envenenamento de cache no momento que pegamos e guardamos papéis dos usuários via Token claims da autenticação.

### Backend (Processo Combinado)
Precisamos analisar uma exportação SQL com as "CREATE POLICY" das tabelas.

## Perguntas em Aberto

1.  **As chaves no arquivo `.env` só contemplam o Supabase (cuja key *anon* já é tecnicamente pública) ou existem *outras coisas confidenciais* ali como chaves do Stripe/Google Maps/SendGrid/Firebase-Admin que seriam expostas?**
2.  **Podemos iniciar mitigando o vazamento em `main.dart` e `pubspec.yaml` enquanto você acessa o painel do Supabase para exportar as regras atuais do banco para mim?**

## Plano de Verificação

### Testes Automatizados
- Compilar uma build debug local via CLI garantindo que variáveis mascaradas sobem perfeitamente.
- Testar `flutter analyze` reportando `No issues found!`.

### Teste Manual
- Simular tentativas de "Admin bypass" via alteração local do JWT ou Cache, certificando-se de que a API retorne *HTTP 401 Unauthorized*.
