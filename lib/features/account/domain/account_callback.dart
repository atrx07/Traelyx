bool isAccountCallback(Uri uri) =>
    uri.scheme == 'io.github.atrx07.traelyx' &&
    uri.host == 'auth-callback' &&
    uri.path == '/';
