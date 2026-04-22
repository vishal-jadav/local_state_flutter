# state_manage_package

A lightweight Flutter state management package by Vishal Jadav.

`state_manage_package` gives you small reactive values that rebuild only the
widgets that are watching them. It is useful for local screen state, form state,
counters, toggles, loading flags, and simple object-wise state without adding a
large state management framework.

## Features

- `ChangeVar<T>` for one reactive value.
- `ChangeObject` for grouped object-wise state.
- `StateBuilder<T>` to rebuild only the widget attached to a changed value.
- `StateSelector<T, S>` to rebuild only when a selected part changes.
- `watch`, `watchAll`, and `select` helpers for concise widget code.
- Direct assignment support: use `count.value++` or `name.value = 'Vishal'`.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  state_manage_package: ^0.0.1
```

Then import it:

```dart
import 'package:state_manage_package/state_manage_package.dart';
```

## Basic Usage

Create a `ChangeVar<T>` and watch it with `StateBuilder<T>`.

```dart
import 'package:flutter/material.dart';
import 'package:state_manage_package/state_manage_package.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final count = ChangeVar<int>(0);

  @override
  void dispose() {
    count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ChangeVar Example')),
      body: Center(
        child: StateBuilder<int>(
          state: count,
          builder: (context, value, child) {
            return Text(
              'Count: $value',
              style: const TextStyle(fontSize: 32),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          count.value++;
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

When `count.value++` runs, only the `StateBuilder<int>` subtree rebuilds. The
parent page does not need `setState`.

## Short Watch Syntax

Every `ChangeVar<T>` also has a `watch` helper:

```dart
final title = ChangeVar<String>('Dashboard');

title.watch(
  (context, value, child) => Text(value),
);
```

Update the value directly:

```dart
title.value = 'Reports';
```

## Object-wise State

Use `ChangeObject` when a screen has multiple related state properties.

```dart
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final profile = ChangeObject({
    'name': 'Vishal',
    'age': 28,
    'isSaving': false,
  });

  @override
  void dispose() {
    profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        profile.watch<String>(
          'name',
          (context, value, child) => Text('Name: $value'),
        ),
        profile.watch<int>(
          'age',
          (context, value, child) => Text('Age: $value'),
        ),
        ElevatedButton(
          onPressed: () {
            profile.property<int>('age').value++;
          },
          child: const Text('Increase age'),
        ),
      ],
    );
  }
}
```

Changing `age` rebuilds only the age watcher. Changing `name` rebuilds only the
name watcher.

## Watch Any Object Property

Use `watchAll` when one block should rebuild after any property in a
`ChangeObject` changes.

```dart
profile.watchAll((context, value, child) {
  return Text('${value['name']} is ${value['age']} years old');
});

profile.set<String>('name', 'Updated');
profile.property<int>('age').value++;
```

Both updates rebuild the `watchAll` block.

## Select a Slice

Use `StateSelector` when a value contains multiple fields and a widget should
rebuild only for one selected part.

```dart
final user = ChangeVar<({String name, int age})>(
  (name: 'Vishal', age: 28),
);

StateSelector<({String name, int age}), String>(
  state: user,
  selector: (value) => value.name,
  builder: (context, name, child) {
    return Text(name);
  },
);
```

Changing only `age` will not rebuild the name widget.

## Mutable Lists and Maps

For collections, prefer assigning a new value:

```dart
final items = ChangeVar<List<String>>([]);

items.value = [...items.value, 'New item'];
```

If you mutate a collection in place, call `mutate`:

```dart
items.mutate((value) {
  value.add('New item');
});
```

## Typed State Classes

For cleaner code, wrap `ChangeObject` keys in your own class.

```dart
class ProfileState extends ChangeObject {
  ProfileState()
    : super({
        'name': 'Vishal',
        'age': 28,
      });

  ChangeProperty<String> get name => property<String>('name');
  ChangeProperty<int> get age => property<int>('age');
}
```

Usage:

```dart
final profile = ProfileState();

profile.name.value = 'Updated';
profile.age.value++;
```

## API Overview

- `ChangeVar<T>`: a listenable value with `value`, `set`, `update`, `mutate`,
  and `refresh`.
- `ChangeObject`: a group of named reactive properties.
- `ChangeProperty<T>`: a typed handle to one `ChangeObject` property.
- `StateBuilder<T>`: rebuilds when a `ValueListenable<T>` changes.
- `ChangeObjectBuilder`: rebuilds when any property in a `ChangeObject`
  changes.
- `StateSelector<T, S>`: rebuilds when a selected value changes.

## Maintainer

Created and maintained by Vishal Jadav.

## Contributing

Contributions are welcome. If you want to contribute, fork the repository,
create a branch for your changes, and raise a pull request targeting the
`main` branch on GitHub.

Please keep changes focused and include tests or documentation updates when
they are relevant.

## License

MIT License. See [LICENSE](LICENSE).
