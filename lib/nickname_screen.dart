import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _nicknameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveNickname() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, escribe un nombre")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Obtenemos el usuario actual
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // 2. Sobrescribimos el nombre de Google con el Nickname elegido
        await user.updateDisplayName(_nicknameController.text.trim());
        await user.reload(); // Confirmamos cambios
      }

      // 3. Volvemos al Login (que nos redirigirá al Mapa automáticamente)
      if (mounted) {
        // Hacemos pop para volver, y el StreamBuilder del main detectará que ya estamos listos
        Navigator.of(context).pop(); 
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit, size: 60, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "Estás entrando con Google, pero...\n¿Cómo quieres que te llamen en la Liga?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: "Tu Nickname",
                hintText: "Ej: FlashGarcía",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveNickname,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("GUARDAR Y ENTRAR"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}