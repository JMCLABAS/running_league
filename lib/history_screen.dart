import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'db_helper.dart';

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

  void _refreshRuns() {
    setState(() {
      _runHistory = DBHelper().getRuns();
    });
  }

  // --- NUEVA FUNCIÓN: LÓGICA DE BORRADO ---
  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("¿Eliminar carrera?"),
          content: const Text("¿Seguro que quieres eliminar esta carrera?"),
          actions: [
            // Botón Cancelar
            TextButton(
              child: const Text("No, Cancelar"),
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo sin hacer nada
              },
            ),
            // Botón Eliminar (Rojo para indicar peligro)
            TextButton(
              child: const Text("Sí, Eliminar", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                // 1. Borramos de la base de datos
                await DBHelper().deleteRun(id);
                
                // 2. Cerramos el diálogo
                if (context.mounted) Navigator.of(context).pop();

                // 3. Recargamos la lista para que desaparezca la tarjeta
                _refreshRuns();
                
                // 4. Feedback al usuario
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Historial 🏃‍♂️'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_run, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text("Aún no has corrido. ¡A por ello!", style: TextStyle(color: Colors.grey)),
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
    // Usamos el formato español
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
            // 1. CABECERA CON FECHA Y BOTÓN DE BORRAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Separa fecha a la izq y botón a la der
              children: [
                // Fecha e icono calendario
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(fechaBonita, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                // --- BOTÓN DE PAPELERA ---
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    // Llamamos a la función de confirmación pasándole el ID de esta carrera
                    _confirmDelete(run['id']);
                  },
                ),
              ],
            ),
            const Divider(),
            
            // 2. DATOS GRANDES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _datoPrincipal("${(run['distance'] / 1000).toStringAsFixed(2)} km", "Distancia"),
                _datoPrincipal(_formatDuration(run['duration']), "Tiempo"),
                _datoPrincipal("${run['avgSpeed']}", "min/km"),
              ],
            ),
            
            const SizedBox(height: 15),
            
            // 3. LOS RÉCORDS
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