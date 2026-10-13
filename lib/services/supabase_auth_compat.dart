import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FirebaseAuth {
  FirebaseAuth._();
  static final instance = FirebaseAuth._();
  User? get currentUser {
    final user = sb.Supabase.instance.client.auth.currentUser;
    return user == null ? null : User(user);
  }
}

class User {
  final sb.User _user;
  User(this._user);
  String get uid => _user.id;
  String? get email => _user.email;
}
