## 0.0.1

* Initial release with `ChangeVar`, `StateBuilder`, and `StateSelector`.
* Added `ChangeObject` and `ChangeProperty` for grouped object-wise state.
* Added `ChangeObjectBuilder` and `watchAll` for rebuilding when any object
  property changes.
* Added `LocalVar` as the local-state name for a single reactive value.
* Added `LocalObject` for auto-disposed state without writing a
  `StatefulWidget`.
* Added `LocalState` and `LocalStateMixin` for simpler auto-disposed
  `StatefulWidget` state.
