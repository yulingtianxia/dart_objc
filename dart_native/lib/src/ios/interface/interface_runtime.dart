import 'dart:async';
import 'dart:ffi';

import 'package:dart_native/dart_native.dart';
import 'package:dart_native/src/ios/common/library.dart';
import 'package:dart_native/src/ios/runtime/internal/nssubclass.dart';

class InterfaceRuntimeObjC extends InterfaceRuntime {
  @override
  Pointer<Void> hostObjectWithInterfaceName(String name) {
    final ptr = NSString(name).pointer;
    return interfaceHostObjectWithName(ptr);
  }

  @override
  Map<String, String> methodTableWithInterfaceName(String name) {
    return _interfaceMetaData[name].cast<String, String>();
  }

  @override
  T invoke<T>(String interfaceName, Pointer<Void> hostObject, String methodName, {List? args}) {
    dynamic result = msgSend(hostObject, SEL(methodName), args: args);
    return _postprocessResult<T>(result);
  }

  @override
  Future<T> invokeAsync<T>(String interfaceName, Pointer<Void> hostObject, String methodName, {List? args}) {
    return msgSendAsync<dynamic>(hostObject, SEL(methodName), args: args).then((value){
      return _postprocessResult<T>(value);
    });
  }

  T _postprocessResult<T>(dynamic result) {
    if (result is NSObject) {
      // The type of result is NSObject, we should unbox it.
      if (T == int || T == double) {
        if (result.isKind(of: Class('NSNumber'))) {
          final number = NSNumber.fromPointer(result.pointer);
          return number.raw;
        }
      } else if (T == String) {
        if (result.isKind(of: Class('NSString'))) {
          final str = NSString.fromPointer(result.pointer);
          return str.raw as T;
        }
      } else if (T == List) {
        if (result.isKind(of: Class('NSArray'))) {
          final array = NSArray.fromPointer(result.pointer);
          return array.raw as T;
        }
      } else if (T == Map) {
        if (result.isKind(of: Class('NSDictionary'))) {
          final dict = NSDictionary.fromPointer(result.pointer);
          return dict.raw as T;
        }
      } else if (T == Set) {
        if (result.isKind(of: Class('NSSet'))) {
          final set = NSSet.fromPointer(result.pointer);
          return set.raw as T;
        }
      }
    } else if (result is NSSubclass) {
      // unbox
      result = result.raw;
    }
    return result;
  }
}

final Pointer<Void> Function(Pointer<Void>) interfaceHostObjectWithName = nativeDylib
    .lookup<NativeFunction<Pointer<Void> Function(Pointer<Void>)>>(
        'DNInterfaceHostObjectWithName')
    .asFunction();

final Pointer<Void> Function() interfaceAllMetaData =
    nativeDylib
        .lookup<NativeFunction<Pointer<Void> Function()>>(
            'DNInterfaceAllMetaData')
        .asFunction();

Map _mapForInterfaceMetaData() {
  Pointer<Void> ptr = interfaceAllMetaData();
  return NSDictionary.fromPointer(ptr).raw;
}

final Map _interfaceMetaData = _mapForInterfaceMetaData();