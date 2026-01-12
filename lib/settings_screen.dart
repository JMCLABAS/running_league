import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

/// Pantalla de Configuración y Perfil.
///
/// Centraliza la gestión de preferencias locales (persistencia de estado de UI)
/// y la administración de la cuenta de usuario (actualización de identidad y cierre de sesión).
class SettingsScreen extends StatefulWidget {
  final bool currentVoiceEnabled;

  const SettingsScreen({super.key, required this.currentVoiceEnabled});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _voiceEnabled;
  final _nicknameController = TextEditingController();
  
  final User? user = FirebaseAuth.instance.currentUser;
  
  bool _isUpdatingName = false;

  @override
  void initState() {
    super.initState();
    // Inicialización del estado local con los parámetros inyectados
    _voiceEnabled = widget.currentVoiceEnabled;
    _nicknameController.text = user?.displayName ?? "";
  }

  /// Ejecuta una actualización de identidad en dos fases (Dual-Write).
  /// Es crítico mantener sincronizados el perfil de Auth (Sesión) y el documento
  /// de Firestore (Público) para garantizar la consistencia en los Rankings.
  Future<void> _updateNickname() async {
    String newName = _nicknameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El nombre no puede estar vacío"))
      );
      return;
    }

    setState(() => _isUpdatingName = true);

    try {
      if (user == null) throw Exception("Error de sesión: Usuario no autenticado");

      // Fase 1: Actualización de metadatos de sesión (Auth)
      await user!.updateDisplayName(newName);
      await user!.reload(); 
      
      // Fase 2: Propagación al modelo de datos público (Firestore)
      // Utilizamos SetOptions(merge: true) para operaciones idempotentes.
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'displayName': newName,
        'email': user!.email,
        'photoURL': user!.photoURL,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Perfil y Ranking actualizados"), backgroundColor: Colors.green),
        );
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingName = false);
    }
  }

  /// Retorna el control a la pantalla anterior pasando el estado modificado.
  /// Esto permite actualizar la configuración en el 'MapScreen' sin necesidad de un gestor de estado global.
  void _goBack() {
    Navigator.pop(context, _voiceEnabled);
  }

  /// Cierre de sesión seguro.
  /// Limpia el stack de navegación (`popUntil`) para prevenir que el usuario
  /// pueda regresar a pantallas protegidas mediante el botón "Atrás" del sistema.
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Patrón de confirmación destructiva para evitar salidas accidentales (UX).
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("¿Cerrar Sesión?"),
          content: const Text("¿Seguro que quieres cerrar sesión?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); 
              },
              child: const Text("No, Cancelar", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); 
                _signOut(); 
              },
              child: const Text("Sí, Cerrar Sesión", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Intercepción del botón "Atrás" del sistema (Android) para garantizar
    // que siempre se ejecute la lógica de retorno de parámetros (_goBack).
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Ajustes"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack, 
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("PREFERENCIAS DE ENTRENAMIENTO", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 10),
            
            // Configuración Local
            Card(
              elevation: 2,
              child: SwitchListTile(
                title: const Text("Entrenador de Voz"),
                subtitle: const Text("Te avisa cada km y al finalizar"),
                secondary: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off, color: Colors.blue),
                value: _voiceEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _voiceEnabled = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 30),
            const Text("MI PERFIL (RANKING)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 10),

            // Configuración de Identidad
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Tu Nickname público"),
                    const Text("Este nombre aparecerá en las tablas de la liga.", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nicknameController,
                            decoration: const InputDecoration(
                              hintText: "Ej. Correcaminos",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isUpdatingName ? null : _updateNickname,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          child: _isUpdatingName 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Guardar"),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text("SESIÓN", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 10),

            // Zona de Peligro / Logout
            Card(
              elevation: 2,
              color: Colors.red[50],
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: _confirmSignOut, 
              ),
            ),
            
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "Running League v1.0", 
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}