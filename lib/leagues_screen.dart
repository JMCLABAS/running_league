import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; 
import 'package:share_plus/share_plus.dart'; // <--- IMPORTANTE: Necesario para compartir
import 'create_league_screen.dart'; 
import 'ranking_screen.dart';

class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // Función para unirse a una liga existente por ID
  void _joinLeagueDialog() {
    final TextEditingController idController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unirse a una Liga"),
        content: TextField(
          controller: idController,
          decoration: const InputDecoration(
            labelText: "ID de la Liga",
            hintText: "Pega aquí el código de la liga",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (idController.text.isNotEmpty) {
                await _joinLeague(idController.text.trim());
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("UNIRME"),
          ),
        ],
      ),
    );
  }

  Future<void> _joinLeague(String leagueId) async {
    try {
      final leagueRef = FirebaseFirestore.instance.collection('leagues').doc(leagueId);
      final doc = await leagueRef.get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Esa liga no existe")));
        return;
      }

      // Añadir mi ID al array de participantes
      await leagueRef.update({
        'participantes': FieldValue.arrayUnion([user!.uid])
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ¡Te has unido a la liga!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- NUEVA FUNCIÓN PARA COMPARTIR ---
  // --- FUNCIÓN PARA COMPARTIR (FORMATO HTTP) ---
  void _compartirLiga(String nombreLiga, String leagueId) {
    // Usamos un dominio "falso" pero con http para que WhatsApp lo ponga azul
    final String link = "https://running-league-app.web.app/unirse?id=$leagueId";
    
    Share.share(
      "¡Únete a mi liga '$nombreLiga'! 🏃💨\n\n"
      "1. Instala la App primero.\n"
      "2. Pincha este enlace para entrar:\n$link"
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("No logueado")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Ligas"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leagues')
            .where('participantes', arrayContains: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text("No estás en ninguna liga aún.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateLeagueScreen()),
                      );
                    },
                    child: const Text("CREAR MI PRIMERA LIGA"),
                  )
                ],
              ),
            );
          }

          final leagues = snapshot.data!.docs;

          return ListView.builder(
            itemCount: leagues.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final league = leagues[index].data() as Map<String, dynamic>;
              final leagueId = leagues[index].id;
              final config = league['configuracionPuntos'] ?? {};

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RankingScreen(
                          leagueId: leagueId,
                          leagueData: league,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // 1. AVATAR (Izquierda)
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blueAccent,
                          child: Text(
                            league['nombre'][0].toUpperCase(), 
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                          ),
                        ),
                        
                        const SizedBox(width: 16), 

                        // 2. TEXTOS (Centro - Flexible)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                league['nombre'], 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                              ),
                              const SizedBox(height: 4),
                              Text("Modo: ${config['modo'] ?? 'FIJO'}"),
                              Text(
                                "${league['participantes'].length} Runners", 
                                style: TextStyle(color: Colors.grey[600], fontSize: 12)
                              ),
                            ],
                          ),
                        ),

                        // 3. BOTONES DE ACCIÓN (Derecha)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // BOTÓN COPIAR ID
                            IconButton(
                                icon: const Icon(Icons.copy, color: Colors.blueGrey, size: 20),
                                tooltip: "Copiar ID",
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: leagueId));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("ID copiado: $leagueId"), duration: const Duration(seconds: 1))
                                    );
                                  }
                                },
                            ),
                            
                            // --- NUEVO BOTÓN COMPARTIR ---
                            IconButton(
                                icon: const Icon(Icons.share, color: Colors.green, size: 20),
                                tooltip: "Invitar Amigos",
                                onPressed: () {
                                    _compartirLiga(league['nombre'], leagueId);
                                },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "join",
            onPressed: _joinLeagueDialog,
            label: const Text("Unirse"),
            icon: const Icon(Icons.group_add),
            backgroundColor: Colors.green,
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "create",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateLeagueScreen()),
              );
            },
            label: const Text("Crear"),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}