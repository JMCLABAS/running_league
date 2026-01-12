import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_screen.dart'; 

/// Pantalla de autenticación principal.
/// Gestiona el inicio de sesión mediante credenciales de correo/contraseña
/// y proveedores federados (Google OAuth).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  /// Autenticación tradicional mediante Firebase Auth.
  /// Incluye validación de correo verificado para garantizar la calidad de los usuarios
  /// antes de permitir el acceso a la plataforma.
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showMessage("Por favor, escribe email y contraseña", color: Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Security check: Gatekeeper para emails no verificados
      if (!userCredential.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        _showMessage("⛔ Debes verificar tu correo para entrar.", color: Colors.red);
        return; 
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
       _showMessage("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Inicio de sesión federado con Google.
  /// Implementa el flujo de OAuth 2.0 intercambiando tokens de Google por credenciales de Firebase.
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // UX Decision: Forzamos el cierre de sesión en el plugin de Google antes de iniciar.
      // Esto garantiza que el selector de cuentas aparezca siempre, permitiendo al usuario
      // cambiar de cuenta si se equivocó anteriormente, en lugar de auto-loguear silenciosamente.
      await _googleSignIn.signOut(); 

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // El usuario canceló el modal de selección
        setState(() => _isLoading = false);
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Intercambio de tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, 
        idToken: googleAuth.idToken,
      );
      
      // La lógica de creación de perfil (onboarding) está delegada en el AuthWrapper (main.dart)
      // para mantener la separación de responsabilidades.
      await FirebaseAuth.instance.signInWithCredential(credential);
      
      _showMessage("¡Conectado con Google!", color: Colors.green);
      
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      
    } catch (e) {
      _showMessage("Error Google: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  /// Mapeo de errores de Firebase a mensajes amigables para el usuario final (i18n ready).
  void _handleFirebaseError(FirebaseAuthException e) {
    String msg = "Error desconocido";
    if (e.code == 'user-not-found' || e.code == 'invalid-credential') msg = "Usuario o contraseña incorrectos";
    else if (e.code == 'wrong-password') msg = "Contraseña incorrecta";
    else if (e.code == 'too-many-requests') msg = "Demasiados intentos. Inténtalo más tarde.";
    _showMessage(msg);
  }

  void _showMessage(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bienvenido Runner")),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_run, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                  obscureText: true,
                ),
                const SizedBox(height: 25),

                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _login, child: const Text("INICIAR SESIÓN"))),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: _goToRegister,
                        child: const Text("¿Nuevo aquí? Crea una cuenta"),
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                          label: const Text("Entrar con Google"),
                        ),
                      ),
                    ],
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}