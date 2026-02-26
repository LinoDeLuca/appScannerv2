import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/fridge_item.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<FridgeItem> _myFridge = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mitt Kylskåp 🍏')),
      // HÄR visar vi listan nu!
      body: _myFridge.isEmpty
          ? const Center(child: Text("Kylen är tom!"))
          : ListView.builder(
              itemCount: _myFridge.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    title: Text(_myFridge[index].name),
                    subtitle: Text(_myFridge[index].expiryDate),
                    trailing: IconButton(
                      icon :const Icon(Icons.delete, color:Colors.red),
                      onPressed:(){
                        setState(() {
                          _myFridge.removeAt(index);
                        });
                      }
                  
                  ),
                )
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add_a_photo),
        onPressed: () async {
          final cameras = await availableCameras();
          // Här hoppar vi till kameran och skickar med funktionen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TakePictureScreen(
                camera: cameras.first,
                onSave: (name, date) {
                  // Denna kod körs när kameran säger "Spara!"
                  setState(() {
                    _myFridge.add(FridgeItem(name: name, expiryDate: date));
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }
} 