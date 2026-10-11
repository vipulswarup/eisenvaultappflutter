# Alfresco 5.2 / 26.1 and Angora authentication compatibility

Verified against the supplied remote servers on 2026-10-10 using the Flutter application's authentication services. No credentials or tickets are recorded here.

| Server | API-discovered version | Authentication | Checks |
| --- | --- | --- | --- |
| demo.eisenvault.net | Community 5.2.0.0 | JSON credentials → repository ticket | Login, profile, saved-ticket validation, sites, search |
| alfresco26.eisenvault.net | Community 26.1.0.0 | JSON credentials → repository ticket | Login, profile, saved-ticket validation, sites, search |
| snoopy.angoradev.in | Angora (separate API) | Email/password → access-token cookie | Login, profile returned by login, authenticated departments |

## Authentication contract

Both Alfresco versions use `POST /alfresco/api/-default-/public/authentication/versions/1/tickets` with JSON `userId` and `password`. Success is HTTP 201 with `entry.id`. An additional username/password Authorization header is unnecessary and has been removed.

Subsequent requests use `Authorization: Basic <base64(ticket)>`. Encode the ticket itself, without adding a colon, password, or Bearer prefix. This contract remains documented for Content Services 26.1. The challenge sent by an unauthenticated endpoint does not change how this documented ticket header is constructed.

These deployments differ in their unauthenticated discovery response:

- 5.2: HTTP 401, `WWW-Authenticate: Basic realm="Alfresco -default- tenant"`, empty body.
- 26.1: HTTP 401, `WWW-Authenticate: AlfTicket realm="Alfresco -default- tenant"`, JSON error body.

The detector recognizes the Alfresco realm under either scheme, or an HTTP 200 discovery JSON response containing `entry.repository`. It sends no credentials. Discovery failures leave the existing Angora-first fallback available.

Alfresco tickets can expire or be invalidated. The application already validates saved Classic sessions through `people/-me-` at startup and requires login again after a 401. It does not automatically refresh Alfresco tickets using a stored password.

Angora remains a separate protocol: `POST /api/auth/login`, JSON `email` and `password`, `x-service-name: service-auth`, and an `accessToken` cookie (with a response-body token fallback). Its login now has a bounded request timeout and accepts an injected HTTP client for regression tests. Raw cookie headers and token previews have been removed from login logging.

## Root cause and fix

The old login handler tried the Angora endpoint first for the Alfresco hostnames. On the 26.1 deployment, `/api/auth/login` returns HTTP 200 **HTML**, rather than a missing-route 404. The app attempted to decode this page as an Angora JSON response and never reached Alfresco login.

The handler now probes `/alfresco/api/discovery` before trying Angora on unknown domains. Both supplied Alfresco hosts are positively identified and go directly to ticket login. Angora domains retain their existing login route. Trailing-slash removal in the login handler has also been corrected.

A missing ESS signing configuration returns 404 on the 5.2 server and remains optional; 26.1 returns 200. Neither determines login success.

## Repeatable checks

Unit tests cover both challenges, public discovery, unrelated Basic challenges, HTML pages, network failure, credential-body ticket creation, missing tickets, rejected profile requests, and Angora cookie/body token extraction.

Run offline tests with `flutter test`. Live tests are opt-in and skipped unless the relevant environment variables are present. Set `ALFRESCO52_URL`, `ALFRESCO52_USERNAME`, `ALFRESCO52_PASSWORD`, `ALFRESCO26_URL`, `ALFRESCO26_USERNAME`, `ALFRESCO26_PASSWORD`, `ANGORA_URL`, `ANGORA_USERNAME`, and `ANGORA_PASSWORD` in your local environment, then run:

```sh
flutter test test/live/repository_login_test.dart
```

Use origin URLs without `/alfresco` for these live-test variables. Tests authenticate and read data only. They do not upload, edit, delete repository content, or revoke tickets shared with another session.

The checks verify the application's service layer against real servers. They do not exercise native login-screen navigation, upload/download, workflow operations, or SSO/Identity Service deployments. An OAuth/SSO-only deployment would require separate testing and potentially an interactive authorization flow.

Validation results: all three live login checks passed; Alfresco browsing/search and Angora departments passed; the ordinary suite passed 93 tests (three opt-in live tests skipped); `flutter build macos --debug` succeeded. Full `flutter analyze` reported seven existing warnings and 341 info diagnostics, with no errors. Analysis of the changed files reported four existing info diagnostics in the login handler.

## Official references

- [Content Services 26.1: Configuring Basic Authentication](https://docs.hyland.com/r/Alfresco/Alfresco-Content-Services/26.1/Alfresco-Content-Services/Develop/REST-API-Guide/Install-and-Authenticate/Authenticate-with-the-Repository/Configuring-Basic-Authentication)
- [Content Services 26.1 REST API Guide](https://docs.hyland.com/r/Alfresco/Alfresco-Content-Services/26.1/Alfresco-Content-Services/Develop/REST-API-Guide)
- [Alfresco official REST authentication guide source](https://github.com/Alfresco/docs-alfresco/blob/master/content-services/6.2/develop/rest-api-guide/install.md)

Documentation for Alfresco **Process Services** describes different authentication behavior. Its Identity Service restrictions must not be applied to these Content Services repository endpoints.
