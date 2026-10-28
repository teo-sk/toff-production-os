# Security

## Supported versions

Security fixes are considered for the latest published framework version on `main` (see [VERSION](VERSION)).

## Reporting a vulnerability

Please **do not** open a public issue for security-sensitive problems (for example: bootstrap path escape, unintended writes outside the target repo, or credential leakage in scripts).

Prefer GitHub’s private vulnerability reporting for this repository when enabled:

**Security → Report a vulnerability** on https://github.com/teo-sk/toff-production-os

If private reporting is unavailable, open a **minimal** public issue that states only that a security concern exists and ask a maintainer to contact you — do not include exploit details, payloads, or private paths in the public issue body.

## Scope notes

- This repository contains process docs, templates, and shell scripts — not a Unity runtime.  
- Third-party products (Unity, Cursor, MCP servers, etc.) have their own security channels.  
- Do not submit secrets, tokens, or personal data in reports.  
