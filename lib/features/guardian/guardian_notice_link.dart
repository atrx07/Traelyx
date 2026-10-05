/// A notice opens the guarded inbox screen; it carries no alert or account data.
bool isGuardianNoticeLink(Uri uri) =>
    uri.scheme == 'io.github.atrx07.traelyx' &&
    uri.host == 'guardian-notice' &&
    uri.path == '/' &&
    uri.userInfo.isEmpty &&
    !uri.hasPort &&
    !uri.hasQuery &&
    !uri.hasFragment;
