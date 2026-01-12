import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pantalla de registro de nuevos usuarios.
///
/// Gestiona el flujo completo de creación de cuenta, incluyendo la configuración
/// inicial del perfil (nickname) y la solicitud de verificación de seguridad por correo.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores de texto para la gestión del estado del formulario
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  /// Ejecuta el proceso de alta en Firebase Auth.
  ///
  /// Este método es transaccional desde la perspectiva del usuario:
  /// 1. Crea la credencial base.
  /// 2. Enriquece el perfil con el Nickname inmediatamente (evita perfiles incompletos).
  /// 3. Dispara el flujo de verificación de email.
  Future<void> _register() async {
    // Validación de entrada temprana (Fail-fast)
    if (_nicknameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty || 
        _passwordController.text.trim().isEmpty) {
      _showMessage("Por favor, rellena todos los campos", color: Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Creación de la identidad en el proveedor de identidad (IdP)
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        // Sincronización inmediata del perfil:
        // Asignamos el display name antes de la primera navegación para asegurar consistencia en la UI.
        await userCredential.user!.updateDisplayName(_nicknameController.text.trim());
        
        // Forzamos la actualización del token local para reflejar los nuevos metadatos
        await userCredential.user!.reload(); 
        
        // Security Gate: Requerimos verificación para habilitar características sociales en el futuro
        await userCredential.user!.sendEmailVerification();
      }

      // Feedback y navegación
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Cuenta creada. ¡Revisa tu correo para verificarla!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        // Retornamos al Login para forzar una autenticación limpia con las nuevas credenciales
        Navigator.of(context).pop(); 
      }

    } on FirebaseAuthException catch (e) {
      // Mapeo de errores de infraestructura a mensajes amigables para el usuario
      String msg = "Error al registrar";
      if (e.code == 'email-already-in-use') msg = "El correo ya está registrado";
      else if (e.code == 'weak-password') msg = "La contraseña es muy débil (mín 6 caracteres)";
      else if (e.code == 'invalid-email') msg = "El formato del correo no es válido";
      _showMessage(msg);
    } catch (e) {
       _showMessage("Error crítico: $e");
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
                
                TextField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: "Nickname (Nombre visible)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  // UX: Capitalización automática para nombres propios
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 15),

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