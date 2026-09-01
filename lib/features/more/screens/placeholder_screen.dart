import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('Bills & subscriptions'),
            subtitle: Text('Coming soon'),
          ),
          ListTile(
            leading: Icon(Icons.pin_drop_outlined),
            title: Text("Who's got pickup"),
            subtitle: Text('Coming soon'),
          ),
          ListTile(
            leading: Icon(Icons.restaurant_menu_outlined),
            title: Text('Meal planning'),
            subtitle: Text('Coming soon'),
          ),
          ListTile(
            leading: Icon(Icons.chat_bubble_outline),
            title: Text('Ask Gemini'),
            subtitle: Text('Coming soon'),
          ),
        ],
      ),
    );
  }
}
