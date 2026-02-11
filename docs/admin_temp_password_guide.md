# Sistema de Senha Temporária para Admins

## 📋 Visão Geral

Sistema completo que permite ao Super Admin criar novos Admins de estabelecimento com senha temporária, forçando a troca de senha no primeiro login e exibindo mensagem de boas-vindas.

## 🔄 Fluxo Completo

```
1. Super Admin registra estabelecimento
   ↓
2. Insere email do Admin no campo "Email do Admin"
   ↓
3. Sistema verifica se usuário existe:
   
   ✅ Usuário EXISTE:
      - Atribui role='admin'
      - Define establishment_id
      - Marca must_change_password=TRUE
   
   ❌ Usuário NÃO EXISTE:
      - Flutter app cria usuário via Supabase Admin SDK
      - Senha temporária: "Manda2024!"
      - Marca must_change_password=TRUE
   ↓
4. Admin faz login
   ↓
5. Sistema detecta must_change_password=TRUE
   ↓
6. Redireciona para ChangePasswordScreen (OBRIGATÓRIO)
   ↓
7. Admin troca senha
   ↓
8. Sistema marca must_change_password=FALSE
   ↓
9. Exibe tela de boas-vindas:
   "Parabéns! Vamos crescer seu negócio juntos! 🚀"
   ↓
10. Após 5 segundos, redireciona para dashboard
```

## 🗄️ Estrutura do Banco de Dados

### Novos Campos em `public.profiles`

```sql
must_change_password BOOLEAN DEFAULT FALSE  -- Indica se precisa trocar senha
welcome_shown BOOLEAN DEFAULT FALSE         -- Indica se já viu mensagem de boas-vindas
```

### RPCs Criadas

1. **`assign_establishment_admin(email, establishment_id)`**
   - Atribui Admin ao estabelecimento
   - Se usuário não existe, retorna `create_required` com senha temporária
   - Se usuário existe, marca `must_change_password=TRUE`

2. **`check_password_change_required()`**
   - Retorna TRUE se usuário precisa trocar senha
   - Chamado após login para verificar

3. **`complete_password_change()`**
   - Marca senha como alterada
   - Define welcome_shown=TRUE
   - Chamado após troca bem-sucedida

## 📱 Arquivos Flutter

### Criados
- `lib/screens/auth/change_password_screen.dart` - Tela de troca de senha forçada + boas-vindas

### Modificados  
- `lib/services/app_translations.dart` - Traduções (EN/PT) para fluxo de senha

## 🔧 Implementação Necessária

### 1. Executar SQL no Supabase
```bash
# Execute este arquivo no Supabase SQL Editor:
server_python/sql/admin_temp_password_system.sql
```

### 2. Modificar `establishment_editor_screen_modern.dart`

No método `_saveEstablishment()`, após chamar a RPC `assign_establishment_admin`:

```dart
final response = await _supabase.rpc('assign_establishment_admin', params: {
  'p_email': _adminEmailController.text.trim(),
  'p_establishment_id': establishmentId,
});

// ADICIONAR:
if (response['status'] == 'create_required') {
  // Usuário não existe, precisa criar
  final email = response['email'];
  final tempPassword = response['temp_password'];
  final estId = response['establishment_id'];
  
  // Criar usuário via Admin SDK
  final adminClient = SupabaseAdmin(
    '<YOUR_SUPABASE_URL>',
    '<YOUR_SERVICE_ROLE_KEY>', // NUNCA exponha isso no código do cliente!
  );
  
  await adminClient.auth.admin.createUser(
    email: email,
    password: tempPassword,
    emailConfirm: true, // Pula confirmação de email
  );
  
  // Agora chamar novamente a RPC para vincular
  await _supabase.rpc('assign_establishment_admin', params: {
    'p_email': email,
    'p_establishment_id': estId,
  });
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Admin criado! Credenciais:\nEmail: $email\nSenha: $tempPassword'),
        duration: const Duration(seconds: 10),
      ),
    );
  }
}
```

**⚠️ IMPORTANTE**: 
- A criação de usuário via Admin SDK deve ser feita em um **backend seguro**, não no Flutter app
- Considere criar uma Cloud Function para isso
- **NUNCA** exponha a `SERVICE_ROLE_KEY` no código do cliente

### 3. Modificar Fluxo de Login

No `login_screen.dart` ou onde você autentica o usuário:

```dart
// Após login bem-sucedido
final needsPasswordChange = await _supabase
    .rpc('check_password_change_required')
    .select();

if (needsPasswordChange == true) {
  // Redirecionar OBRIGATORIAMENTE para troca de senha
  if (mounted) {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(isRequired: true),
      ),
    );
    
    if (changed != true) {
      // Se não trocou senha, não permitir acesso
      await _supabase.auth.signOut();
      return;
    }
  }
}

// Continuar para dashboard
```

## 🌐 Traduções Adicionadas

### Português
- `firstLoginTitle`: "Bem-vindo à Manda.AI!"
- `firstLoginSubtitle`: "Para sua segurança, por favor altere sua senha temporária."
- `welcomeTitle`: "Parabéns!"
- `welcomeMessage`: "Vamos crescer seu negócio juntos! 🚀"
- `newPassword`: "Nova Senha"
- `confirmPassword`: "Confirmar Senha"
- `changePasswordButton`: "ALTERAR SENHA"
- `passwordChanged`: "Senha alterada com sucesso!"
- `passwordTooShort`: "A senha deve ter pelo menos 8 caracteres"
- `passwordsDoNotMatch`: "As senhas não coincidem"

### English
- `firstLoginTitle`: "Welcome to Manda.AI!"
- `firstLoginSubtitle`: "For your security, please change your temporary password."
- `welcomeTitle`: "Congratulations!"
- `welcomeMessage`: "Let's grow your business together! 🚀"
- (e demais traduções correspondentes)

## 🔐 Segurança

✅ **Implementado:**
- RLS garante que apenas Super Admin pode atribuir Admins
- Senha temporária complexa (`Manda2024!`)
- Troca de senha obrigatória no primeiro login
- Validação de senha mínima de 8 caracteres

⚠️ **Recomendações:**
- Implementar Cloud Function para criação de usuários
- Enviar credenciais por email seguro (não por SnackBar)
- Considerar expiração de senha temporária (ex: 24h)
- Adicionar log de auditoria

## 🚀 Próximos Passos

1. [ ] Executar `admin_temp_password_system.sql` no Supabase
2. [ ] Implementar lógica de criação de usuário (Cloud Function)
3. [ ] Integrar check de `must_change_password` no fluxo de login
4. [ ] Testar fluxo completo
5. [ ] Configurar envio de email com credenciais

## 📞 Suporte

Para dúvidas ou problemas, consulte a documentação do Supabase sobre [Admin API](https://supabase.com/docs/reference/javascript/auth-admin-createuser).
