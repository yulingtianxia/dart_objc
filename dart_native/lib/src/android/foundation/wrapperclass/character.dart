import 'dart:ffi';

import 'package:dart_native/dart_native.dart';
import 'package:dart_native/src/android/runtime/jsubclass.dart';

/// Stands for `Character` in Android.
const String CLS_CHARACTER = "java/lang/Character";

class JCharacter extends JSubclass<int> {
  JCharacter(int value) : super(value, _new, CLS_CHARACTER);

  JCharacter.fromPointer(Pointer<Void> ptr)
      : super.fromPointer(ptr, CLS_CHARACTER) {
    raw = invoke("charValue", [], "C");
  }
}

/// New native 'Character'.
Pointer<Void> _new(dynamic value, String clsName) {
  if (value is int) {
    JObject object = JObject(clsName, args: [jchar(value)]);
    return object.pointer.cast<Void>();
  } else {
    throw 'Invalid param when initializing Character.';
  }
}
