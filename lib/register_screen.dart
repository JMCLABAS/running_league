import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores
  final _nicknameController = TextEditingController(); // <--- NUEVO
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _register() async {
    // 1. Validaciones básicas
    if (_nicknameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty || 
        _passwordController.text.trim().isEmpty) {
      _showMessage("Por favor, rellena todos los campos", color: Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 2. Crear el usuario en Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 3. Guardar el Nickname (DisplayName) en el perfil del usuario
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(_nicknameController.text.trim());
        await userCredential.user!.reload(); // Recargar para asegurar que se guarda
        
        // 4. Enviar correo de verificación
        await userCredential.user!.sendEmailVerification();
      }

      // 5. Mensaje de éxito y volver al Login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Cuenta creada. ¡Revisa tu correo para verificarla!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        // Volvemos atrás (al Login) para que entre con sus datos
        Navigator.of(context).pop(); 
      }

    } on FirebaseAuthException catch (e) {
      String msg = "Error al registrar";
      if (e.code == 'email-already-in-use') msg = "El correo ya está registrado";
      else if (e.code == 'weak-password') msg = "La contraseña es muy débil (mín 6 caracteres)";
      else if (e.code == 'invalid-email') msg = "El formato del correo no es válido";
      _showMessage(msg);
    } catch (e) {
       _showMessage("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      appBar: AppBar(title: const Text("Crear Cuenta")),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Icon(Icons.person_add, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                
                // --- CAMPO NICKNAME ---
                TextField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: "Nickname (Nombre visible)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 15),

                // CAMPO EMAIL
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Correo Electrónico",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                
                // CAMPO CONTRASEÑA
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "Contraseña",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 25),

                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("REGISTRARME"),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}