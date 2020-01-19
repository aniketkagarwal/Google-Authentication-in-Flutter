import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum SignInOption {
  standard,
  games
}

class GoogleSignInUserData {
  GoogleSignInUserData(
      {this.displayName, this.email, this.idToken});
  String displayName;
  String email;
  String idToken;

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! GoogleSignInUserData) return false;
    final GoogleSignInUserData otherUserData = other;
    return otherUserData.displayName == displayName &&
        otherUserData.email == email &&
        otherUserData.idToken == idToken;
  }
}

class GoogleSignInTokenData {
  GoogleSignInTokenData({this.idToken, this.accessToken});
  String idToken;
  String accessToken;

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! GoogleSignInTokenData) return false;
    final GoogleSignInTokenData otherTokenData = other;
    return otherTokenData.idToken == idToken &&
        otherTokenData.accessToken == accessToken;
  }
}

GoogleSignInUserData getUserDataFromMap(Map<String, dynamic> data) {
  if (data == null) {
    return null;
  }
  return GoogleSignInUserData(
      displayName: data['displayName'],
      email: data['email'],
      idToken: data['idToken']);
}

GoogleSignInTokenData getTokenDataFromMap(Map<String, dynamic> data) {
  if (data == null) {
    return null;
  }
  return GoogleSignInTokenData(
    idToken: data['idToken'],
    accessToken: data['accessToken'],
  );
}

class MethodChannelGoogleSignIn extends GoogleSignInPlatform {

  @override
  Future<void> init(
      {@required String hostedDomain,
        List<String> scopes = const <String>[],
        SignInOption signInOption = SignInOption.standard,
        String clientId}) {
    return channel.invokeMethod<void>('init', <String, dynamic>{
      'signInOption': signInOption.toString(),
      'scopes': scopes,
      'hostedDomain': hostedDomain,
    });
  }

  @override
  Future<GoogleSignInUserData> signInSilently() {
    return channel
        .invokeMapMethod<String, dynamic>('signInSilently')
        .then(getUserDataFromMap);
  }

  @override
  Future<GoogleSignInUserData> signIn() {
    return channel
        .invokeMapMethod<String, dynamic>('signIn')
        .then(getUserDataFromMap);
  }

  @override
  Future<GoogleSignInTokenData> getTokens(
      {String email, bool shouldRecoverAuth = true}) {
    return channel
        .invokeMapMethod<String, dynamic>('getTokens', <String, dynamic>{
      'email': email,
      'shouldRecoverAuth': shouldRecoverAuth,
    }).then(getTokenDataFromMap);
  }

  @override
  Future<void> signOut() {
    return channel.invokeMapMethod<String, dynamic>('signOut');
  }

  @override
  Future<void> disconnect() {
    return channel.invokeMapMethod<String, dynamic>('disconnect');
  }
}

abstract class GoogleSignInPlatform {
  @visibleForTesting
  bool get isMock => false;
  static GoogleSignInPlatform get instance => _instance;
  static GoogleSignInPlatform _instance = MethodChannelGoogleSignIn();
  static set instance(GoogleSignInPlatform instance) {
    if (!instance.isMock) {
      try {
        instance._verifyProvidesDefaultImplementations();
      } on NoSuchMethodError catch (_) {
        throw AssertionError(
            'Platform interfaces must not be implemented with `implements`');
      }
    }
    _instance = instance;
  }
  void _verifyProvidesDefaultImplementations() {}
  Future<void> init(
      {@required String hostedDomain,
        List<String> scopes,
        SignInOption signInOption,
        String clientId}) async {
    throw UnimplementedError('init() has not been implemented.');
  }
  Future<GoogleSignInUserData> signInSilently() async {
    throw UnimplementedError('signInSilently() has not been implemented.');
  }
  Future<GoogleSignInUserData> signIn() async {
    throw UnimplementedError('signIn() has not been implemented.');
  }
  Future<GoogleSignInTokenData> getTokens(
      {@required String email, bool shouldRecoverAuth}) async {
    throw UnimplementedError('getTokens() has not been implemented.');
  }
  Future<void> signOut() async {
    throw UnimplementedError('signOut() has not been implemented.');
  }
  Future<void> disconnect() async {
    throw UnimplementedError('disconnect() has not been implemented.');
  }
}

abstract class GoogleIdentity {
  String get email;
  String get displayName;
}

class GoogleSignInAuthentication {
  GoogleSignInAuthentication._(this._data);
  final GoogleSignInTokenData _data;
  String get idToken => _data.idToken;
  String get accessToken => _data.accessToken;

  @override
  String toString() => 'GoogleSignInAuthentication:$_data';
}

class GoogleSignInAccount implements GoogleIdentity {
  GoogleSignInAccount._(this._googleSignIn, GoogleSignInUserData data)
      : displayName = data.displayName,
        email = data.email,
        _idToken = data.idToken {}

  static const String kFailedToRecoverAuthError = 'failed_to_recover_auth';
  static const String kUserRecoverableAuthError = 'user_recoverable_auth';

  @override
  final String displayName;

  @override
  final String email;

  final String _idToken;
  final GoogleSignIn _googleSignIn;

  Future<GoogleSignInAuthentication> get authentication async {
    if (_googleSignIn.currentUser != this) {
      throw StateError('User is no longer signed in.');
    }

    final GoogleSignInTokenData response =
    await GoogleSignInPlatform.instance.getTokens(
      email: email,
      shouldRecoverAuth: true,
    );
    if (response.idToken == null) {
      response.idToken = _idToken;
    }
    return GoogleSignInAuthentication._(response);
  }
  Future<Map<String, String>> get authHeaders async {
    final String token = (await authentication).accessToken;
    return <String, String>{
      "Authorization": "Bearer $token",
      "X-Goog-AuthUser": "0",
    };
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! GoogleSignInAccount) return false;
    final GoogleSignInAccount otherAccount = other;
    return displayName == otherAccount.displayName &&
        email == otherAccount.email &&
        _idToken == otherAccount._idToken;
  }

  @override
  int get hashCode => hashValues(displayName, email, _idToken);

  @override
  String toString() {
    final Map<String, dynamic> data = <String, dynamic>{
      'displayName': displayName,
      'email': email,
    };
    return 'GoogleSignInAccount:$data';
  }
}

class GoogleSignIn {
  GoogleSignIn({
    this.signInOption = SignInOption.standard,
    this.scopes = const <String>[],
    this.hostedDomain,
    this.clientId,
  });

  factory GoogleSignIn.standard({
    List<String> scopes = const <String>[],
    String hostedDomain,
  }) {
    return GoogleSignIn(
        signInOption: SignInOption.standard,
        scopes: scopes,
        hostedDomain: hostedDomain);
  }

  static const String kSignInRequiredError = 'sign_in_required';
  static const String kSignInCanceledError = 'sign_in_canceled';
  static const String kNetworkError = 'network_error';
  static const String kSignInFailedError = 'sign_in_failed';
  final SignInOption signInOption;
  final List<String> scopes;
  final String hostedDomain;
  final String clientId;

  StreamController<GoogleSignInAccount> _currentUserController =
  StreamController<GoogleSignInAccount>.broadcast();

  Stream<GoogleSignInAccount> get onCurrentUserChanged =>
      _currentUserController.stream;

  Future<void> _initialization;

  Future<GoogleSignInAccount> _callMethod(Function method) async {
    await _ensureInitialized();

    final dynamic response = await method();

    return _setCurrentUser(response != null && response is GoogleSignInUserData
        ? GoogleSignInAccount._(this, response)
        : null);
  }

  GoogleSignInAccount _setCurrentUser(GoogleSignInAccount currentUser) {
    if (currentUser != _currentUser) {
      _currentUser = currentUser;
      _currentUserController.add(_currentUser);
    }
    return _currentUser;
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= GoogleSignInPlatform.instance.init(
      signInOption: signInOption,
      scopes: scopes,
      hostedDomain: hostedDomain,
      clientId: clientId,
    )..catchError((dynamic _) {
      _initialization = null;
    });
  }

  Future<void> _lastMethodCall;

  static Future<void> _waitFor(Future<void> future) {
    final Completer<void> completer = Completer<void>();
    future.whenComplete(completer.complete).catchError((dynamic _) {});
    return completer.future;
  }

  Future<GoogleSignInAccount> _addMethodCall(
      Function method, {
        bool canSkipCall = false,
      }) async {
    Future<GoogleSignInAccount> response;
    if (_lastMethodCall == null) {
      response = _callMethod(method);
    } else {
      response = _lastMethodCall.then((_) {
        if (canSkipCall && _currentUser != null) {
          return _currentUser;
        }
        return _callMethod(method);
      });
    }
    _lastMethodCall = _waitFor(response);
    return response;
  }

  GoogleSignInAccount get currentUser => _currentUser;
  GoogleSignInAccount _currentUser;

  Future<GoogleSignInAccount> signInSilently({
    bool suppressErrors = true,
  }) async {
    try {
      return await _addMethodCall(GoogleSignInPlatform.instance.signInSilently,
          canSkipCall: true);
    } catch (_) {
      if (suppressErrors) {
        return null;
      } else {
        rethrow;
      }
    }
  }

  Future<GoogleSignInAccount> signIn() {
    final Future<GoogleSignInAccount> result =
    _addMethodCall(GoogleSignInPlatform.instance.signIn, canSkipCall: true);
    bool isCanceled(dynamic error) =>
        error is PlatformException && error.code == kSignInCanceledError;
    return result.catchError((dynamic _) => null, test: isCanceled);
  }

  Future<GoogleSignInAccount> signOut() =>
      _addMethodCall(GoogleSignInPlatform.instance.signOut);

  Future<GoogleSignInAccount> disconnect() =>
      _addMethodCall(GoogleSignInPlatform.instance.disconnect);
}
