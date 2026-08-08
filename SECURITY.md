# Traelyx — Security Rules and Reporting

## Security posture

Traelyx handles location history, sensor telemetry, account identity, social relationships, and optional user-supplied API keys. Treat compromise or unintended disclosure as high impact even though the project is non-commercial.

## Secrets — never commit

The repository must reject/ignore at minimum:

```text
*.jks
*.keystore
key.properties
.env
.env.*
**/secrets.*
**/*api-key*
```

Do not blindly ignore example configuration files needed for development; use sanitized `.example` files where appropriate.

Never log:

- full access/refresh tokens;
- password material;
- cloud provider API keys;
- release signing passwords;
- unredacted authorization headers.

## Release signing

The release private key is controlled by the maintainer. It must not be generated, uploaded, rotated, or replaced by an agent without explicit maintainer instruction. Initial production signing should happen on a trusted maintainer machine. See `docs/technical/RELEASE_SIGNING.md`.

## Authentication

- Do not implement custom password hashing/authentication if Supabase Auth covers the use case.
- Authorization must be enforced server-side with RLS/policies, not merely by hiding UI.
- Public profile/ranking access must not permit arbitrary private route enumeration.

## Location/privacy

- Precise route data is private by default.
- Leaderboards use derived/sanitized ranking records and must not require public raw trips.
- Guardian access is explicit, permission-scoped, revocable, and audited.
- Cloud commentary must receive sanitized event dossiers by default, not exact coordinates or full raw streams.

## Dependency security

Follow `docs/governance/DEPENDENCY_POLICY.md`. New dependencies need license, maintenance, security, binary-size, and data-flow review.

## Vulnerability reporting placeholder

Before public release, replace this section with a project-specific private security contact or GitHub Security Advisories workflow. Do not encourage public disclosure of active vulnerabilities before a fix is available.
