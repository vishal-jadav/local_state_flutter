/// Lightweight local state helpers for Flutter widgets.
///
/// Use [LocalVar] for a single reactive value, [ChangeObject] for grouped
/// values, and [LocalObject] when you want Flutter to keep and dispose local
/// state automatically.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Builds a widget from the current value of a [ChangeVar].
typedef StateWidgetBuilder<T> =
    Widget Function(BuildContext context, T value, Widget? child);

/// Selects a smaller value from a larger state object.
typedef StateValueSelector<T, S> = S Function(T value);

/// Decides whether a selected value should trigger a rebuild.
typedef StateShouldRebuild<S> = bool Function(S previous, S next);

/// A tiny observable value for local, SwiftUI `@State`-style state.
///
/// Each [ChangeVar] owns one value. Widgets subscribe to it with
/// [StateBuilder], so changing this value only rebuilds the subscribed widget
/// subtree instead of the whole parent screen.
///
/// Assign to [value] directly to notify listeners:
///
/// ```dart
/// count.value++;
/// title.value = 'Updated';
/// ```
class ChangeVar<T> extends ChangeNotifier implements ValueListenable<T> {
  /// Creates a state value with [initialValue].
  ChangeVar(T initialValue) : _value = initialValue;

  T _value;

  /// The current value.
  @override
  T get value => _value;

  /// Replaces the current value and notifies listeners when it actually
  /// changes according to `==`.
  ///
  /// You do not need to call [update] or [refresh] after assigning this value.
  set value(T nextValue) {
    if (_value == nextValue) {
      return;
    }

    _value = nextValue;
    notifyListeners();
  }

  /// Replaces the current value.
  void set(T nextValue) {
    value = nextValue;
  }

  /// Updates the current value from its previous value.
  void update(T Function(T currentValue) updater) {
    value = updater(_value);
  }

  /// Mutates the current value in place and notifies listeners.
  ///
  /// This is useful for mutable values such as [List] and [Map]. Prefer
  /// assigning immutable replacement values when possible.
  void mutate(void Function(T currentValue) mutator) {
    mutator(_value);
    notifyListeners();
  }

  /// Notifies listeners without replacing the value.
  void refresh() {
    notifyListeners();
  }
}

/// A locally owned reactive value.
///
/// [LocalVar] has the same behavior as [ChangeVar], but the name is intended
/// for values created inside [LocalObject] and [LocalState].
class LocalVar<T> extends ChangeVar<T> {
  /// Creates a local state value with [initialValue].
  LocalVar(super.initialValue);
}

/// A typed handle to one named property inside a [ChangeObject].
///
/// This can be used anywhere a [ValueListenable] is accepted, including
/// [StateBuilder]. Assigning to [value] rebuilds only widgets watching this
/// property.
class ChangeProperty<T> implements ValueListenable<T> {
  ChangeProperty._({required this.key, required ChangeVar<Object?> state})
    : _state = state;

  /// The property name inside its [ChangeObject].
  final String key;

  final ChangeVar<Object?> _state;

  /// The current typed property value.
  @override
  T get value {
    final currentValue = _state.value;
    if (currentValue is T) {
      return currentValue;
    }

    throw StateError(
      'Change property "$key" contains ${currentValue.runtimeType}, '
      'not $T.',
    );
  }

  /// Replaces the current property value and notifies this property's widgets.
  set value(T nextValue) {
    _state.value = nextValue;
  }

  /// Replaces the current property value.
  void set(T nextValue) {
    value = nextValue;
  }

  /// Updates the current property value from its previous value.
  void update(T Function(T currentValue) updater) {
    value = updater(value);
  }

  /// Mutates the current property value in place and notifies listeners.
  void mutate(void Function(T currentValue) mutator) {
    mutator(value);
    _state.refresh();
  }

  /// Notifies listeners without replacing the value.
  void refresh() {
    _state.refresh();
  }

  @override
  void addListener(VoidCallback listener) {
    _state.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _state.removeListener(listener);
  }
}

/// A grouped object of independent named state properties.
///
/// Use this when a screen or feature has object-wise state:
///
/// ```dart
/// final form = ChangeObject({
///   'name': '',
///   'age': 0,
/// });
///
/// form.property<String>('name').value = 'Vishal';
/// form.property<int>('age').value++;
/// ```
///
/// Each property is backed by its own state value. Widgets can watch one
/// property with [property] or watch the full object with [ChangeObjectBuilder].
class ChangeObject extends ChangeNotifier
    implements ValueListenable<Map<String, Object?>> {
  /// Creates a state object from named initial values.
  ChangeObject(Map<String, Object?> initialValues) {
    for (final entry in initialValues.entries) {
      _addProperty(entry.key, entry.value);
    }
  }

  final _properties = <String, ChangeVar<Object?>>{};

  /// The property names defined in this object.
  Iterable<String> get keys => _properties.keys;

  /// A read-only snapshot of current property values.
  @override
  Map<String, Object?> get value => snapshot;

  /// A read-only snapshot of current property values.
  Map<String, Object?> get snapshot {
    return Map.unmodifiable({
      for (final entry in _properties.entries) entry.key: entry.value.value,
    });
  }

  /// Returns whether [key] exists.
  bool contains(String key) {
    return _properties.containsKey(key);
  }

  /// Returns a typed property handle for [key].
  ChangeProperty<T> property<T>(String key) {
    return ChangeProperty<T>._(key: key, state: _stateFor(key));
  }

  /// Reads a typed property value.
  T get<T>(String key) {
    return property<T>(key).value;
  }

  /// Assigns a typed property value.
  void set<T>(String key, T value) {
    property<T>(key).value = value;
  }

  /// Updates a typed property value from its previous value.
  void update<T>(String key, T Function(T currentValue) updater) {
    property<T>(key).update(updater);
  }

  /// Adds a new property.
  void add<T>(String key, T initialValue) {
    if (_properties.containsKey(key)) {
      throw StateError('Change property "$key" already exists.');
    }

    _addProperty(key, initialValue);
    notifyListeners();
  }

  /// Removes and disposes a property.
  ///
  /// Returns `true` when a property existed.
  bool remove(String key) {
    final state = _properties.remove(key);
    if (state == null) {
      return false;
    }

    state.removeListener(_handlePropertyChanged);
    state.dispose();
    notifyListeners();
    return true;
  }

  /// Disposes all property values.
  @override
  void dispose() {
    for (final state in _properties.values) {
      state.removeListener(_handlePropertyChanged);
      state.dispose();
    }
    _properties.clear();
    super.dispose();
  }

  ChangeVar<Object?> _stateFor(String key) {
    final state = _properties[key];
    if (state == null) {
      throw StateError('Change property "$key" is not defined.');
    }

    return state;
  }

  void _addProperty(String key, Object? initialValue) {
    final state = ChangeVar<Object?>(initialValue)
      ..addListener(_handlePropertyChanged);
    _properties[key] = state;
  }

  void _handlePropertyChanged() {
    notifyListeners();
  }
}

/// A widget with built-in, auto-disposed local state.
///
/// Extend this when you want local state without writing a separate
/// [StatefulWidget] and [State] class:
///
/// ```dart
/// class CounterPage extends LocalObject {
///   @override
///   Widget build(BuildContext context, LocalObjectState local) {
///     final count = local.state(0);
///     return count.watch((context, value, child) => Text('$value'));
///   }
/// }
/// ```
abstract class LocalObject extends StatefulWidget {
  /// Creates a local object widget.
  const LocalObject({super.key});

  @override
  LocalObjectState createState() => LocalObjectState();

  /// Builds this widget with access to auto-disposed local state.
  Widget build(BuildContext context, LocalObjectState local);
}

/// Stores local state for a [LocalObject].
class LocalObjectState extends State<LocalObject> {
  final _managedStates = <Object, ChangeNotifier>{};
  var _buildIndex = 0;

  /// Creates or returns a [LocalVar] for this build position.
  ///
  /// Use [key] when the state is created conditionally or inside loops.
  LocalVar<T> state<T>(T initialValue, {Object? key}) {
    return manage<LocalVar<T>>(_stateKey(key), () => LocalVar<T>(initialValue));
  }

  /// Creates or returns a [ChangeObject] for this build position.
  ///
  /// Use [key] when the state is created conditionally or inside loops.
  ChangeObject objectState(Map<String, Object?> initialValues, {Object? key}) {
    return manage<ChangeObject>(
      _stateKey(key),
      () => ChangeObject(initialValues),
    );
  }

  /// Creates or returns a managed [ChangeNotifier] for [key].
  T manage<T extends ChangeNotifier>(Object key, T Function() create) {
    final notifier = _managedStates[key];
    if (notifier == null) {
      final createdNotifier = create();
      _managedStates[key] = createdNotifier;
      return createdNotifier;
    }

    if (notifier is T) {
      return notifier;
    }

    throw StateError(
      'LocalObject state "$key" contains ${notifier.runtimeType}, not $T.',
    );
  }

  @override
  Widget build(BuildContext context) {
    _buildIndex = 0;
    return widget.build(context, this);
  }

  @override
  void dispose() {
    for (final notifier in _managedStates.values.toList().reversed) {
      notifier.dispose();
    }
    _managedStates.clear();
    super.dispose();
  }

  Object _stateKey(Object? key) {
    return key ?? _LocalObjectSlot(_buildIndex++);
  }
}

class _LocalObjectSlot {
  const _LocalObjectSlot(this.index);

  final int index;

  @override
  bool operator ==(Object other) {
    return other is _LocalObjectSlot && other.index == index;
  }

  @override
  int get hashCode => Object.hash(_LocalObjectSlot, index);
}

/// Adds auto-disposed local state helpers to a [StatefulWidget] [State].
///
/// Use this mixin when your state class already needs to extend [State]:
///
/// ```dart
/// class _CounterPageState extends State<CounterPage>
///     with LocalStateMixin<CounterPage> {
///   late final count = state(0);
/// }
/// ```
mixin LocalStateMixin<W extends StatefulWidget> on State<W> {
  final _managedStates = <ChangeNotifier>{};

  /// Creates a [LocalVar] that is disposed automatically with this widget.
  LocalVar<T> state<T>(T initialValue) {
    return manage(LocalVar<T>(initialValue));
  }

  /// Creates a [ChangeObject] that is disposed automatically with this widget.
  ChangeObject objectState(Map<String, Object?> initialValues) {
    return manage(ChangeObject(initialValues));
  }

  /// Registers a [ChangeNotifier] to be disposed automatically.
  ///
  /// This is useful when you create your own [ChangeNotifier] subclass and want
  /// it to share the same lifecycle as state created with [state].
  T manage<T extends ChangeNotifier>(T notifier) {
    _managedStates.add(notifier);
    return notifier;
  }

  @override
  void dispose() {
    for (final notifier in _managedStates.toList().reversed) {
      notifier.dispose();
    }
    _managedStates.clear();
    super.dispose();
  }
}

/// A simpler [State] base class with auto-disposed local state helpers.
///
/// Extend this instead of [State] when you want to create local state without
/// writing your own `dispose` method:
///
/// ```dart
/// class _CounterPageState extends LocalState<CounterPage> {
///   late final count = state(0);
/// }
/// ```
abstract class LocalState<W extends StatefulWidget> extends State<W>
    with LocalStateMixin<W> {}

/// Rebuilds only this widget subtree when [state] changes.
class StateBuilder<T> extends StatelessWidget {
  /// Creates a widget that listens to [state].
  const StateBuilder({
    required this.state,
    required this.builder,
    super.key,
    this.child,
  });

  /// The state value to observe.
  final ValueListenable<T> state;

  /// Builds from the latest [state] value.
  final StateWidgetBuilder<T> builder;

  /// A stable child passed back to [builder] without rebuilding.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: state,
      builder: builder,
      child: child,
    );
  }
}

/// Rebuilds when any property in a [ChangeObject] changes.
class ChangeObjectBuilder extends StatelessWidget {
  /// Creates a widget that listens to the full [state] object.
  const ChangeObjectBuilder({
    required this.state,
    required this.builder,
    super.key,
    this.child,
  });

  /// The state object to observe.
  final ChangeObject state;

  /// Builds from a snapshot of all current property values.
  final StateWidgetBuilder<Map<String, Object?>> builder;

  /// A stable child passed back to [builder] without rebuilding.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return StateBuilder<Map<String, Object?>>(
      state: state,
      builder: builder,
      child: child,
    );
  }
}

/// Rebuilds only when the selected part of [state] changes.
class StateSelector<T, S> extends StatefulWidget {
  /// Creates a selector for a derived value from [state].
  const StateSelector({
    required this.state,
    required this.selector,
    required this.builder,
    super.key,
    this.shouldRebuild,
    this.child,
  });

  /// The state value to observe.
  final ValueListenable<T> state;

  /// Selects the value used by [builder].
  final StateValueSelector<T, S> selector;

  /// Builds from the selected value.
  final StateWidgetBuilder<S> builder;

  /// Custom comparison for selected values.
  ///
  /// Defaults to rebuilding when `previous != next`.
  final StateShouldRebuild<S>? shouldRebuild;

  /// A stable child passed back to [builder] without rebuilding.
  final Widget? child;

  @override
  State<StateSelector<T, S>> createState() => _StateSelectorState<T, S>();
}

class _StateSelectorState<T, S> extends State<StateSelector<T, S>> {
  late S _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selector(widget.state.value);
    widget.state.addListener(_handleStateChanged);
  }

  @override
  void didUpdateWidget(covariant StateSelector<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_handleStateChanged);
      _selectedValue = widget.selector(widget.state.value);
      widget.state.addListener(_handleStateChanged);
      return;
    }

    final nextSelectedValue = widget.selector(widget.state.value);
    if (_shouldRebuild(_selectedValue, nextSelectedValue)) {
      _selectedValue = nextSelectedValue;
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_handleStateChanged);
    super.dispose();
  }

  void _handleStateChanged() {
    final nextSelectedValue = widget.selector(widget.state.value);
    if (!_shouldRebuild(_selectedValue, nextSelectedValue)) {
      return;
    }

    setState(() {
      _selectedValue = nextSelectedValue;
    });
  }

  bool _shouldRebuild(S previous, S next) {
    return widget.shouldRebuild?.call(previous, next) ?? previous != next;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _selectedValue, widget.child);
  }
}

/// Convenience widget helpers on [ChangeVar].
extension ChangeVarWidgetExtension<T> on ChangeVar<T> {
  /// Creates a [StateBuilder] for this state value.
  Widget watch(StateWidgetBuilder<T> builder, {Key? key, Widget? child}) {
    return StateBuilder<T>(
      key: key,
      state: this,
      builder: builder,
      child: child,
    );
  }

  /// Creates a [StateSelector] for this state value.
  Widget select<S>(
    StateValueSelector<T, S> selector,
    StateWidgetBuilder<S> builder, {
    Key? key,
    StateShouldRebuild<S>? shouldRebuild,
    Widget? child,
  }) {
    return StateSelector<T, S>(
      key: key,
      state: this,
      selector: selector,
      builder: builder,
      shouldRebuild: shouldRebuild,
      child: child,
    );
  }
}

/// Convenience widget helpers on [ChangeProperty].
extension ChangePropertyWidgetExtension<T> on ChangeProperty<T> {
  /// Creates a [StateBuilder] for this property.
  Widget watch(StateWidgetBuilder<T> builder, {Key? key, Widget? child}) {
    return StateBuilder<T>(
      key: key,
      state: this,
      builder: builder,
      child: child,
    );
  }

  /// Creates a [StateSelector] for this property.
  Widget select<S>(
    StateValueSelector<T, S> selector,
    StateWidgetBuilder<S> builder, {
    Key? key,
    StateShouldRebuild<S>? shouldRebuild,
    Widget? child,
  }) {
    return StateSelector<T, S>(
      key: key,
      state: this,
      selector: selector,
      builder: builder,
      shouldRebuild: shouldRebuild,
      child: child,
    );
  }
}

/// Convenience widget helpers on [ChangeObject].
extension ChangeObjectWidgetExtension on ChangeObject {
  /// Creates a [ChangeObjectBuilder] that rebuilds when any property changes.
  Widget watchAll(
    StateWidgetBuilder<Map<String, Object?>> builder, {
    Key? key,
    Widget? child,
  }) {
    return ChangeObjectBuilder(
      key: key,
      state: this,
      builder: builder,
      child: child,
    );
  }

  /// Creates a [StateBuilder] for a named property.
  Widget watch<T>(
    String key,
    StateWidgetBuilder<T> builder, {
    Key? widgetKey,
    Widget? child,
  }) {
    return StateBuilder<T>(
      key: widgetKey,
      state: property<T>(key),
      builder: builder,
      child: child,
    );
  }

  /// Creates a [StateSelector] for a named property.
  Widget select<T, S>(
    String key,
    StateValueSelector<T, S> selector,
    StateWidgetBuilder<S> builder, {
    Key? widgetKey,
    StateShouldRebuild<S>? shouldRebuild,
    Widget? child,
  }) {
    return StateSelector<T, S>(
      key: widgetKey,
      state: property<T>(key),
      selector: selector,
      builder: builder,
      shouldRebuild: shouldRebuild,
      child: child,
    );
  }
}
