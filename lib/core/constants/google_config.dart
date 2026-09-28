class GoogleConfig {
  GoogleConfig._();

  // The Web application OAuth client ID from Google Cloud Console (NOT the
  // Android client ID) -- passed as GoogleSignIn's serverClientId so Google
  // issues ID tokens with this as the audience, matching what the backend's
  // GOOGLE_CLIENT_ID verifies against. Override per environment:
  //   --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxxxxxxx.apps.googleusercontent.com
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}
