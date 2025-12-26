import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'history_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Instancia CLÁSICA (Funciona perfecto en v6.2.1)
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- LOGIN CON EMAIL ---
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showMessage("Por favor, escribe email y contraseña", color: Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
       _showMessage("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REGISTRO CON EMAIL ---
  Future<void> _register() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showMessage("Rellena los campos para registrarte", color: Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _showMessage("¡Cuenta creada!", color: Colors.green);
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
       _showMessage("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIN CON GOOGLE (VERSIÓN ESTABLE v6) ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. Iniciar sesión (Método clásico)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // Cancelado por usuario
      }

      // 2. Obtener tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Credencial para Firebase
      // En la versión 6, accessToken SÍ existe y es bueno usarlo.
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, 
        idToken: googleAuth.idToken,
      );

      // 4. Entrar en Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);
      _showMessage("¡Conectado con Google!", color: Colors.green);
      
    } catch (e) {
      _showMessage("Error Google: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    String msg = "Error desconocido";
    if (e.code == 'user-not-found') msg = "Usuario no encontrado";
    else if (e.code == 'wrong-password') msg = "Contraseña incorrecta";
    else if (e.code == 'email-already-in-use') msg = "Email ya registrado";
    else if (e.code == 'invalid-credential') msg = "Credenciales inválidas";
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
                      TextButton(onPressed: _register, child: const Text("¿No tienes cuenta? Regístrate aquí")),
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