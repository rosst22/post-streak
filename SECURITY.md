# Security Policy

## Reporting a vulnerability

Do not open a public issue for suspected vulnerabilities or exposed data. Email
`rosstoma@gmail.com` with the affected component, reproduction steps, potential
impact, and any suggested mitigation.

Do not access, modify, or retain another person's data while testing. Reports will
be acknowledged as soon as practical and handled before public disclosure.

## Secrets

This repository must never contain a Supabase secret/service-role key, database
password, Apple signing private key, access token, refresh token, or production
`.env` file. The iOS Supabase publishable key is intentionally public and is not an
authorization boundary; FastAPI verifies the user's JWT and owns authorization.

