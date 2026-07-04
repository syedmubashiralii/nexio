# Security Policy

## Supported Release

Security fixes target the latest published `0.1.x` release. Upgrade to the
latest patch before reporting behavior that may already be fixed.

## Reporting a Vulnerability

Do not include exploit details, tokens, keys, personal data, or backend URLs in
a public issue.

Use GitHub's private vulnerability reporting or security-advisory flow. If
private reporting is not enabled, open a minimal issue requesting a private
contact channel without disclosing the vulnerability.

Include privately:

- affected Nexio version and Flutter/Dart versions;
- Android or iOS version;
- minimal reproduction without real secrets;
- expected and observed behavior;
- impact and known mitigations.

## Package Security Boundaries

Nexio does not own backend authentication, secure key delivery, certificate
pinning, encrypted local storage, or transaction idempotency. Review the
[security guide](doc/security.md) and
[production checklist](doc/production-checklist.md) before deployment.
