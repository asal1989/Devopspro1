/// The signed-in user, mapped from whatever auth provider was used
/// (Google, Apple, email/password) into one shape the rest of the app
/// depends on — so no screen needs to know it's using Firebase Auth.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });
}
