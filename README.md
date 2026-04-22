# state_manage_package

A lightweight Flutter state management package by Vishal Jadav.

`state_manage_package` gives you small reactive values that rebuild only the
widgets that are watching them. It is useful for local screen state, form state,
counters, toggles, loading flags, and simple object-wise state without adding a
large state management framework.

## Features

- `ChangeVar<T>` for one reactive value.
- `LocalVar<T>` for auto-disposed local values created by `LocalObject`.
- `ChangeObject` for grouped object-wise state.
- `LocalObject` for auto-disposed state without writing a `StatefulWidget`.
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

Extend `LocalObject` and create local values inside `build`. You do not need
to write a constructor, a `StatefulWidget`, a separate `State` class, or a
manual `dispose` method.

```dart
import 'package:flutter/material.dart';
import 'package:state_manage_package/state_manage_package.dart';

class CounterPage extends LocalObject {
  @override
  Widget build(BuildContext context, LocalObjectState local) {
    final count = local.state(0);

    return Scaffold(
      appBar: AppBar(title: const Text('ChangeVar Example')),
      body: Center(
        child: count.watch((context, value, child) {
          return Text(
            'Count: $value',
            style: const TextStyle(fontSize: 32),
          );
        }),
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

`local.state(0)` returns a `LocalVar<int>`. Update it directly with
`count.value++`, `count.value = 10`, or `count.set(10)`.

When `count.value++` runs, only the `count.watch` subtree rebuilds. The parent
page does not need `setState`, and `count` is disposed automatically
when the widget is removed.

## LocalVar

Use `LocalVar<T>` when you need one local value.

```dart
class SearchPage extends LocalObject {
  @override
  Widget build(BuildContext context, LocalObjectState local) {
    final query = local.state('');

    return Column(
      children: [
        query.watch((context, value, child) => Text('Search: $value')),
        TextField(
          onChanged: (value) {
            query.value = value;
          },
        ),
      ],
    );
  }
}
```

You can also create one directly when you want to manage disposal yourself:

```dart
final count = LocalVar<int>(0);
```

## Multiple Local Values

Create as many values as you need with `local.state`.

```dart
class DashboardPage extends LocalObject {
  @override
  Widget build(BuildContext context, LocalObjectState local) {
    final title = local.state('Dashboard');
    final isLoading = local.state(false);

    return Column(
      children: [
        title.watch((context, value, child) => Text(value)),
        isLoading.watch((context, value, child) {
          return Switch(
            value: value,
            onChanged: (nextValue) {
              isLoading.value = nextValue;
            },
          );
        }),
        ElevatedButton(
          onPressed: () {
            title.value = 'Reports';
          },
          child: const Text('Change title'),
        ),
      ],
    );
  }
}
```

For conditional state or state created inside loops, pass a stable `key`:

```dart
final filter = local.state('all', key: 'filter');
```

## Object-wise State

Use `ChangeObject` when a screen has multiple related state properties.

```dart
class ProfilePage extends LocalObject {
  @override
  Widget build(BuildContext context, LocalObjectState local) {
    final profile = local.objectState({
      'name': 'Vishal',
      'age': 28,
      'isSaving': false,
    });

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
- `LocalVar<T>`: the local-state name for a single reactive value. It behaves
  like `ChangeVar<T>` and is returned by `local.state`.
- `ChangeObject`: a group of named reactive properties.
- `ChangeProperty<T>`: a typed handle to one `ChangeObject` property.
- `LocalObject`: a widget base class that creates and auto-disposes local state
  without a separate `StatefulWidget` class.
- `LocalObjectState`: the local state handle passed into `LocalObject.build`.
- `LocalState`: a `State` base class that creates and auto-disposes local
  state with `state` and `objectState` when you already need a `State` class.
- `LocalStateMixin`: the same lifecycle helpers as a mixin for existing
  `State` classes.
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
