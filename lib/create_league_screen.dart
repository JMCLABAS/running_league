import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pantalla de creación de nuevas ligas competitivas.
///
/// Gestiona la inicialización del documento en Firestore, la asignación de
/// permisos de administrador y la configuración de las reglas de gamificación.
class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  
  // Estado de la configuración de la liga
  String _selectedSystem = 'FIJO'; 
  int _targetDaysPerWeek = 3;      
  bool _isLoading = false;

  /// Valida la entrada del usuario y persiste la nueva configuración en Firestore.
  /// Asigna automáticamente al usuario actual como administrador y primer participante.
  Future<void> _createLeague() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Fail-safe: Se requiere autenticación para establecer la propiedad (adminId).
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuario no autenticado");
      }

      // Construcción del payload siguiendo el esquema de la colección 'leagues'.
      final leagueData = {
        "nombre": _nameController.text.trim(),
        "adminId": user.uid,
        "participantes": [user.uid], // El creador se une automáticamente
        "fechaCreacion": FieldValue.serverTimestamp(),
        
        // Configuración del Motor de Gamificación
        // Estos parámetros serán consumidos por las Cloud Functions para el cálculo de puntajes semanales.
        "configuracionPuntos": {
          "modo": _selectedSystem, 
          "diasObjetivoSemana": _targetDaysPerWeek,
          "bonusDiasObjetivo": 100, 
        }
      };

      // Escritura en BBDD
      await FirebaseFirestore.instance.collection('leagues').add(leagueData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Liga creada con éxito! 🏃‍♂️💨')),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear liga: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva Liga")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- Sección de Identidad ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Liga',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.emoji_events_outlined),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Escribe un nombre' : null,
              ),
              const SizedBox(height: 20),

              // --- Reglas de Puntuación ---
              const Text("Sistema de Puntuación",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text("Modo Fijo (Sencillo)"),
                        subtitle: const Text("1 km = 10 puntos."),
                        value: 'FIJO',
                        groupValue: _selectedSystem,
                        onChanged: (val) => setState(() => _selectedSystem = val!),
                      ),
                      RadioListTile<String>(
                        title: const Text("Modo Horquillas (Pro)"),
                        subtitle: const Text("Puntos progresivos. Cuanto más lejos llegas, más vale cada km."),
                        value: 'HORQUILLAS',
                        groupValue: _selectedSystem,
                        onChanged: (val) => setState(() => _selectedSystem = val!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Configuración de Engagement (Frecuencia) ---
              const Text("Objetivo semanal de salidas",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text("¿Cuántos días a la semana deben correr para el bonus?"),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _targetDaysPerWeek.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      label: "$_targetDaysPerWeek días",
                      onChanged: (val) => setState(() => _targetDaysPerWeek = val.round()),
                    ),
                  ),
                  Text("$_targetDaysPerWeek días", 
                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              
              const SizedBox(height: 30),

              // --- Acciones ---
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createLeague,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("CREAR LIGA", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}