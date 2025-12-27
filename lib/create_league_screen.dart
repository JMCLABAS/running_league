import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  
  // Valores por defecto
  String _selectedSystem = 'FIJO'; // Opciones: 'FIJO', 'HORQUILLAS'
  int _targetDaysPerWeek = 3;      // Slider de 1 a 7
  bool _isLoading = false;

  // Función para guardar en Firestore
  Future<void> _createLeague() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Obtener el usuario actual (necesitamos su ID)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuario no autenticado");
      }

      // 2. Preparar los datos (Estructura definida en nuestro chat)
      final leagueData = {
        "nombre": _nameController.text.trim(),
        "adminId": user.uid,
        "participantes": [user.uid], // El creador es el primer participante
        "fechaCreacion": FieldValue.serverTimestamp(),
        
        // AQUÍ ESTÁ LA CONFIGURACIÓN DE PUNTOS
        "configuracionPuntos": {
          "modo": _selectedSystem, // "FIJO" o "HORQUILLAS"
          "diasObjetivoSemana": _targetDaysPerWeek,
          "bonusDiasObjetivo": 100, // Valor fijo por defecto o editable si quieres
        }
      };

      // 3. Guardar en la colección 'leagues'
      await FirebaseFirestore.instance.collection('leagues').add(leagueData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Liga creada con éxito! 🏃‍♂️💨')),
        );
        Navigator.pop(context); // Volver atrás
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
              // --- CAMPO NOMBRE ---
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

              // --- SELECTOR DE SISTEMA DE PUNTUACIÓN ---
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

              // --- SLIDER DE DÍAS OBJETIVO ---
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

              // --- BOTÓN DE GUARDAR ---
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