import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

/// Pantalla de Onboarding para configuración de perfil.
/// Se asegura de que cada usuario tenga un identificador público (nickname)
/// necesario para las tablas de clasificación.
class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  /// Persiste la identidad del usuario en dos capas:
  /// 1. Firebase Auth Profile: Para acceso rápido en sesión local.
  /// 2. Firestore 'users' collection: Para indexación pública en rankings y búsquedas.
  Future<void> _saveNickname() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String nickname = _controller.text.trim();

      // Capa 1: Actualización de metadatos de sesión (Auth)
      await user.updateDisplayName(nickname);
      await user.reload(); 

      // Capa 2: Sincronización con Base de Datos Pública (Firestore)
      // Utilizamos SetOptions(merge: true) como estrategia de UPSERT idempotente.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': nickname,
        'email': user.email,
        'photoURL': user.photoURL, 
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Perfil creado correctamente! 🚀")),
        );
        // Finalización del flujo de onboarding
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Elige tu nombre de Runner")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.badge, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                "¿Cómo quieres aparecer en los Rankings?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Tu Nickname",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) =>
                    val != null && val.isNotEmpty ? null : "Escribe un nombre",
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveNickname,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("EMPEZAR A CORRER", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}