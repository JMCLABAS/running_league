import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; // <--- IMPORTANTE: Para saber quién eres
import 'db_helper.dart';
import 'login_screen.dart'; // Para volver al login al salir

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _runHistory;

  @override
  void initState() {
    super.initState();
    _refreshRuns();
  }

  // --- CAMBIO CLAVE: AHORA FILTRAMOS POR USUARIO ---
  void _refreshRuns() {
    setState(() {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Si hay usuario, pedimos SUS carreras
        _runHistory = DBHelper().getUserRuns(user.uid);
      } else {
        // Si no hay usuario (raro), devolvemos lista vacía
        _runHistory = Future.value([]);
      }
    });
  }

  // --- LOGOUT (Para probar cuentas distintas) ---
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Volvemos a la pantalla de Login y borramos el historial de navegación
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("¿Eliminar carrera?"),
          content: const Text("¿Seguro que quieres eliminar esta carrera?"),
          actions: [
            TextButton(
              child: const Text("No, Cancelar"),
              onPressed: () {
                Navigator.of(context).pop(); 
              },
            ),
            TextButton(
              child: const Text("Sí, Eliminar", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await DBHelper().deleteRun(id);
                if (context.mounted) Navigator.of(context).pop();
                _refreshRuns();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("🗑️ Carrera eliminada")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el usuario para mostrar su email o foto si quisiéramos
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Historial 🏃‍♂️'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          // BOTÓN DE CERRAR SESIÓN (Nuevo)
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Cerrar Sesión",
            onPressed: _signOut,
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _runHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_run, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    user != null ? "Hola ${user.email?.split('@')[0]}" : "Hola Runner",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text("Tu historial está vacío.", style: TextStyle(color: Colors.grey)),
                  const Text("¡Sal a correr para llenarlo!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final runs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: runs.length,
            itemBuilder: (context, index) {
              final run = runs[index];
              return _buildRunCard(run);
            },
          );
        },
      ),
    );
  }

  Widget _buildRunCard(Map<String, dynamic> run) {
    DateTime fecha = DateTime.parse(run['date']);
    String fechaBonita = DateFormat("d MMM yyyy - HH:mm", "es").format(fecha);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(fechaBonita, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    _confirmDelete(run['id']);
                  },
                ),
              ],
            ),
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _datoPrincipal("${(run['distance'] / 1000).toStringAsFixed(2)} km", "Distancia"),
                _datoPrincipal(_formatDuration(run['duration']), "Tiempo"),
                _datoPrincipal("${run['avgSpeed']}", "min/km"),
              ],
            ),
            
            const SizedBox(height: 15),
            
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _filaRecord("Mejor Km Continuo", run['bestRollingTime'], run['bestRollingRange']),
                  const SizedBox(height: 5),
                  _filaRecord("Mejor Km Redondo", run['bestSplitTime'], run['bestSplitRange']),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _datoPrincipal(String valor, String etiqueta) {
    return Column(
      children: [
        Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(etiqueta, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _filaRecord(String titulo, String tiempo, String rango) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        Row(
          children: [
            Text(tiempo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (rango != "-")
              Text(" ($rango)", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}