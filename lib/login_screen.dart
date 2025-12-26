import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Instancia clásica para Google Sign In
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  // --- LOGIN CON EMAIL (AHORA ESTRICTO) ---
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showMessage("Por favor, escribe email y contraseña", color: Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Intentamos entrar
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. SEGURIDAD: ¿Tiene el correo verificado?
      if (!userCredential.user!.emailVerified) {
        // SI NO LO TIENE:
        await FirebaseAuth.instance.signOut(); // Le echamos fuera
        
        _showMessage("⛔ Debes verificar tu correo para entrar. Revisa tu bandeja de entrada.", color: Colors.red);
        
        // Cortamos aquí para que NO pase al mapa
        return; 
      }

      // 3. Si llega aquí, es que está verificado -> PASAR
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

  // --- LOGIN CON GOOGLE ---
  // (Google ya verifica los correos, así que aquí no hace falta bloquear)
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, 
        idToken: googleAuth.idToken,
      );
      
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

  // --- NAVEGAR AL REGISTRO ---
  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    String msg = "Error desconocido";
    if (e.code == 'user-not-found' || e.code == 'invalid-credential') msg = "Usuario o contraseña incorrectos";
    else if (e.code == 'wrong-password') msg = "Contraseña incorrecta";
    else if (e.code == 'too-many-requests') msg = "Demasiados intentos. Espera un poco.";
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