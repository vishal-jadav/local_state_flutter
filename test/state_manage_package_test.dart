import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_manage_package/state_manage_package.dart';

void main() {
  test('ChangeVar notifies listeners when the value changes', () {
    final count = ChangeVar<int>(0);
    var notifications = 0;

    count.addListener(() {
      notifications++;
    });

    count.value = 1;
    count.value = 1;
    count.update((value) => value + 1);

    expect(count.value, 2);
    expect(notifications, 2);
  });

  test('ChangeVar notifies when value is incremented directly', () {
    final count = ChangeVar<int>(0);
    var notifications = 0;

    count.addListener(() {
      notifications++;
    });

    count.value++;

    expect(count.value, 1);
    expect(notifications, 1);
  });

  test('ChangeVar can notify after mutable values are changed in place', () {
    final items = ChangeVar<List<int>>(<int>[]);
    var notifications = 0;

    items.addListener(() {
      notifications++;
    });

    items.mutate((value) {
      value.add(1);
    });

    expect(items.value, <int>[1]);
    expect(notifications, 1);
  });

  test('LocalVar behaves like ChangeVar', () {
    final count = LocalVar<int>(0);
    var notifications = 0;

    count.addListener(() {
      notifications++;
    });

    count.value++;

    expect(count, isA<ChangeVar<int>>());
    expect(count.value, 1);
    expect(notifications, 1);
  });

  test('ChangeObject manages named state properties', () {
    final profile = ChangeObject({'name': 'Asha', 'age': 30});
    var objectNotifications = 0;
    var nameNotifications = 0;
    var ageNotifications = 0;

    profile.addListener(() {
      objectNotifications++;
    });
    final name = profile.property<String>('name');
    final age = profile.property<int>('age');
    name.addListener(() {
      nameNotifications++;
    });
    age.addListener(() {
      ageNotifications++;
    });

    name.value = 'Vishal';
    age.value++;

    expect(profile.get<String>('name'), 'Vishal');
    expect(profile.get<int>('age'), 31);
    expect(profile.snapshot, <String, Object?>{'name': 'Vishal', 'age': 31});
    expect(objectNotifications, 2);
    expect(nameNotifications, 1);
    expect(ageNotifications, 1);

    profile.add<bool>('isPremium', false);
    profile.set<bool>('isPremium', true);

    expect(profile.get<bool>('isPremium'), isTrue);
    expect(profile.remove('isPremium'), isTrue);
    expect(profile.contains('isPremium'), isFalse);
    expect(objectNotifications, 5);

    profile.dispose();
  });

  testWidgets('StateBuilder rebuilds only the widget bound to changed state', (
    tester,
  ) async {
    final count = ChangeVar<int>(0);
    final title = ChangeVar<String>('Initial');
    var parentBuilds = 0;
    var countBuilds = 0;
    var titleBuilds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            parentBuilds++;

            return Column(
              children: <Widget>[
                StateBuilder<int>(
                  state: count,
                  builder: (context, value, child) {
                    countBuilds++;
                    return Text('Count: $value');
                  },
                ),
                StateBuilder<String>(
                  state: title,
                  builder: (context, value, child) {
                    titleBuilds++;
                    return Text('Title: $value');
                  },
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(parentBuilds, 1);
    expect(countBuilds, 1);
    expect(titleBuilds, 1);
    expect(find.text('Count: 0'), findsOneWidget);
    expect(find.text('Title: Initial'), findsOneWidget);

    count.value++;
    await tester.pump();

    expect(parentBuilds, 1);
    expect(countBuilds, 2);
    expect(titleBuilds, 1);
    expect(find.text('Count: 1'), findsOneWidget);
    expect(find.text('Title: Initial'), findsOneWidget);

    title.value = 'Changed';
    await tester.pump();

    expect(parentBuilds, 1);
    expect(countBuilds, 2);
    expect(titleBuilds, 2);
    expect(find.text('Count: 1'), findsOneWidget);
    expect(find.text('Title: Changed'), findsOneWidget);
  });

  testWidgets('LocalState creates and disposes widget-owned state', (
    tester,
  ) async {
    final tracker = _TrackingNotifier();
    LocalVar<int>? count;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _LocalStateCounter(
          tracker: tracker,
          onStateReady: (value) {
            count = value;
          },
        ),
      ),
    );

    expect(find.text('Count: 0'), findsOneWidget);

    count!.value++;
    await tester.pump();

    expect(find.text('Count: 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tracker.isDisposed, isTrue);
  });

  testWidgets('LocalObject creates state without StatefulWidget boilerplate', (
    tester,
  ) async {
    final tracker = _TrackingNotifier();
    LocalVar<int>? count;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _LocalObjectCounter(
          tracker: tracker,
          onStateReady: (value) {
            count = value;
          },
        ),
      ),
    );

    expect(find.text('Count: 0'), findsOneWidget);

    count!.value++;
    await tester.pump();

    expect(find.text('Count: 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tracker.isDisposed, isTrue);
  });

  testWidgets('StateSelector ignores updates outside the selected value', (
    tester,
  ) async {
    final profile = ChangeVar<({int age, String name})>((
      age: 30,
      name: 'Asha',
    ));
    var nameBuilds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StateSelector<({int age, String name}), String>(
          state: profile,
          selector: (value) => value.name,
          builder: (context, value, child) {
            nameBuilds++;
            return Text(value);
          },
        ),
      ),
    );

    expect(nameBuilds, 1);
    expect(find.text('Asha'), findsOneWidget);

    profile.value = (age: 31, name: 'Asha');
    await tester.pump();

    expect(nameBuilds, 1);
    expect(find.text('Asha'), findsOneWidget);

    profile.value = (age: 31, name: 'Vishal');
    await tester.pump();

    expect(nameBuilds, 2);
    expect(find.text('Vishal'), findsOneWidget);
  });

  testWidgets(
    'ChangeObject rebuilds only the widget bound to changed property',
    (tester) async {
      final profile = ChangeObject({'name': 'Asha', 'age': 30});
      var parentBuilds = 0;
      var nameBuilds = 0;
      var ageBuilds = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              parentBuilds++;

              return Column(
                children: <Widget>[
                  profile.watch<String>('name', (context, value, child) {
                    nameBuilds++;
                    return Text('Name: $value');
                  }),
                  profile.property<int>('age').watch((context, value, child) {
                    ageBuilds++;
                    return Text('Age: $value');
                  }),
                ],
              );
            },
          ),
        ),
      );

      expect(parentBuilds, 1);
      expect(nameBuilds, 1);
      expect(ageBuilds, 1);
      expect(find.text('Name: Asha'), findsOneWidget);
      expect(find.text('Age: 30'), findsOneWidget);

      profile.property<int>('age').value++;
      await tester.pump();

      expect(parentBuilds, 1);
      expect(nameBuilds, 1);
      expect(ageBuilds, 2);
      expect(find.text('Name: Asha'), findsOneWidget);
      expect(find.text('Age: 31'), findsOneWidget);

      profile.set<String>('name', 'Vishal');
      await tester.pump();

      expect(parentBuilds, 1);
      expect(nameBuilds, 2);
      expect(ageBuilds, 2);
      expect(find.text('Name: Vishal'), findsOneWidget);
      expect(find.text('Age: 31'), findsOneWidget);

      profile.dispose();
    },
  );

  testWidgets('ChangeObject watchAll rebuilds when any property changes', (
    tester,
  ) async {
    final profile = ChangeObject({'name': 'Asha', 'age': 30});
    var parentBuilds = 0;
    var objectBuilds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            parentBuilds++;

            return profile.watchAll((context, value, child) {
              objectBuilds++;
              return Text('${value['name']} is ${value['age']}');
            });
          },
        ),
      ),
    );

    expect(parentBuilds, 1);
    expect(objectBuilds, 1);
    expect(find.text('Asha is 30'), findsOneWidget);

    profile.property<int>('age').value++;
    await tester.pump();

    expect(parentBuilds, 1);
    expect(objectBuilds, 2);
    expect(find.text('Asha is 31'), findsOneWidget);

    profile.set<String>('name', 'Vishal');
    await tester.pump();

    expect(parentBuilds, 1);
    expect(objectBuilds, 3);
    expect(find.text('Vishal is 31'), findsOneWidget);

    profile.dispose();
  });
}

class _TrackingNotifier extends ChangeNotifier {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

class _LocalStateCounter extends StatefulWidget {
  const _LocalStateCounter({required this.tracker, required this.onStateReady});

  final _TrackingNotifier tracker;
  final ValueChanged<LocalVar<int>> onStateReady;

  @override
  State<_LocalStateCounter> createState() => _LocalStateCounterState();
}

class _LocalStateCounterState extends LocalState<_LocalStateCounter> {
  late final count = state(0);
  late final tracker = manage(widget.tracker);

  @override
  Widget build(BuildContext context) {
    widget.onStateReady(count);

    return KeyedSubtree(
      key: ValueKey(tracker.isDisposed),
      child: count.watch((context, value, child) {
        return Text('Count: $value');
      }),
    );
  }
}

class _LocalObjectCounter extends LocalObject {
  const _LocalObjectCounter({
    required this.tracker,
    required this.onStateReady,
  });

  final _TrackingNotifier tracker;
  final ValueChanged<LocalVar<int>> onStateReady;

  @override
  Widget build(BuildContext context, LocalObjectState local) {
    final count = local.state(0);
    local.manage('tracker', () => tracker);
    onStateReady(count);

    return count.watch((context, value, child) {
      return Text('Count: $value');
    });
  }
}
