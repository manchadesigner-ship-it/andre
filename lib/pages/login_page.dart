import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  String _perfil = 'gestor'; // padrões: admin, gestor, atendente
  bool _loading = false;
  String? _error;
  bool _isSignUp = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Login] initState');
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Preencha e-mail e senha';
      });
      return;
    }
    if (_isSignUp && pass.length < 6) {
      setState(() {
        _loading = false;
        _error = 'A senha deve ter pelo menos 6 caracteres';
      });
      return;
    }
    if (_isSignUp && _nomeCtrl.text.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Informe o nome completo';
      });
      return;
    }
    debugPrint('[Auth] submit isSignUp=$_isSignUp email=$email');
    try {
      if (_isSignUp) {
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: pass,
          emailRedirectTo: Uri.base.origin,
        );
        debugPrint('[SignUp] done, user=${res.user?.id} session=${res.session != null}');
        // Guarda info para completar perfil após confirmação de e-mail
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_email', email);
        await prefs.setString('pending_nome', _nomeCtrl.text.trim());
        await prefs.setString('pending_perfil', _perfil);
        if (res.session == null) {
          // Geralmente exige verificação de e-mail
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cadastro realizado. Verifique seu e-mail para confirmar a conta.')),
            );
          }
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: pass,
        );
        debugPrint('[Login] sucesso');
      }
    } on AuthException catch (e) {
      debugPrint('[Auth][AuthException] ${e.message}');
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('[Auth][ERROR] $e');
      setState(() => _error = 'Erro inesperado');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Informe o e-mail para reenviar confirmação');
      return;
    }
    debugPrint('[Auth] resend confirmation email=$email');
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail de confirmação reenviado. Verifique sua caixa de entrada.')),
        );
      }
    } on AuthException catch (e) {
      debugPrint('[Auth][Resend][AuthException] ${e.message}');
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('[Auth][Resend][ERROR] $e');
      setState(() => _error = 'Erro ao reenviar confirmação');
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Informe o e-mail para recuperar a senha');
      return;
    }
    debugPrint('[Auth] reset password email=$email');
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: Uri.base.origin,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail de recuperação enviado. Verifique sua caixa de entrada.')),
        );
      }
    } on AuthException catch (e) {
      debugPrint('[Auth][ResetPwd][AuthException] ${e.message}');
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('[Auth][ResetPwd][ERROR] $e');
      setState(() => _error = 'Erro ao enviar recuperação de senha');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Login] build');
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_isSignUp ? 'Criar conta' : 'Entrar', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (_isSignUp) ...[
                      TextField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome completo'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _perfil,
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'gestor', child: Text('Gestor')),
                          DropdownMenuItem(value: 'atendente', child: Text('Atendente')),
                        ],
                        onChanged: (v) => setState(() => _perfil = v ?? 'gestor'),
                        decoration: const InputDecoration(labelText: 'Perfil'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'Cadastrar' : 'Entrar'),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _loading ? null : _resendConfirmation,
                          child: const Text('Reenviar confirmação'),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _resetPassword,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                              }),
                      child: Text(_isSignUp
                          ? 'Já tem conta? Entrar'
                          : 'Novo por aqui? Criar conta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
