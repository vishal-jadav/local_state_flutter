import 'package:flutter/material.dart';
import 'package:state_manage_package/state_manage_package.dart';

void main() {
  runApp(const LocalStateExampleApp());
}

class LocalStateExampleApp extends StatelessWidget {
  const LocalStateExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Local State Example')),
        body: const Padding(padding: EdgeInsets.all(24), child: ExamplePage()),
      ),
    );
  }
}

class ExamplePage extends LocalObject {
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context, LocalObjectState local) {
    final count = local.state(0);
    final query = local.state('');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        count.watch((context, value, child) {
          return Text(
            'Count: $value',
            style: Theme.of(context).textTheme.headlineMedium,
          );
        }),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            count.value++;
          },
          child: const Text('Increment'),
        ),
        const SizedBox(height: 24),
        TextField(
          decoration: const InputDecoration(labelText: 'Search'),
          onChanged: (value) {
            query.value = value;
          },
        ),
        const SizedBox(height: 12),
        query.watch((context, value, child) {
          return Text('Search query: $value');
        }),
      ],
    );
  }
}
