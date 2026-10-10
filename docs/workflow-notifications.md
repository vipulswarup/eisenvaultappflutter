# Workflow notifications: client foundation and server contract

## Implemented scope

The client can consume a durable authenticated inbox and display native OS
notifications on Android, iOS, macOS and Windows (also Linux). Any task category
uses the same assignment event, including approvals and signatures. Alerts contain
no document names, task descriptions or credentials. Events are scoped to saved
signed-in accounts, deduplicated by event ID (last 1,000 retained per account),
and polled every 60 seconds while the app process runs. Polling also runs on
resume and authentication changes. It is not background remote push.

This feature is disabled by default until the proposed endpoint exists. Enable
with `flutter run --dart-define=WORKFLOW_NOTIFICATIONS=true` on a native target.
Permission is requested after sign-in. Denial is respected by the OS; users can
change it in system settings. Cursor advances after processing a page; delivery
is best-effort, and successful API calls do not prove a user saw an alert.

Notification taps require a currently signed-in saved account. The app switches
to that account and re-fetches task ownership through the existing Classic /
Alfresco workflow screen. Angora workflow navigation is not implemented in this
repo; taps currently show a message directing the user to the server inbox.

## Server API (proposed, must be implemented)

All paths are relative to the account's configured base URL. Accept the existing
account Authorization header. Resolve recipient and tenant from authenticated
identity; never trust the submitted accountId to grant access. No provider secrets
belong in the app. Use HTTPS in production.

### GET /eisenvault/api/v1/notifications?limit=100&cursor=OPAQUE

Return only events belonging to the authenticated recipient. First request with
no cursor returns a stable current watermark and events from the server's chosen
retention window. Cursors must be opaque, account-bound, monotonically advancing,
and retained across empty pages. Never silently reset an expired cursor: return
410 and define a recovery policy before enabling production use (client currently
retains the cursor and retries). 401/403 require authentication repair, 404 means
feature absent. Events must be ordered and at most 100 per page. Backlog drains at
one page per poll. Keep an event ID stable across inbox and every push attempt.

```json
{
  "events": [{
    "version": 1,
    "type": "workflow.task.assigned",
    "eventId": "unique-assignment-event",
    "accountId": "client-account-id",
    "taskId": "activiti$123"
  }],
  "nextCursor": "opaque-watermark"
}
```

The client account ID is SHA-256 of `username|baseUrl` as computed by Account.
Registration provides it as correlation metadata; authorization still comes from
the session. Different base URL spellings can yield different IDs. Server inbox
implementation needs a verified registration mapping or an independently checked
canonical base URL/username mapping before returning these envelopes.

Emit after the assignment transaction commits, on initial assignment, subsequent
steps and reassignment. Use an outbox so failed provider sends can be retried.
Expand eligible group recipients server-side; suppress initiator/start tasks,
completed tasks and recipients without current access. Do not filter by known
approval task names: custom signature and other steps must also emit events.

### PUT /eisenvault/api/v1/notification-devices/{installationId}

Idempotent upsert for this authenticated recipient and installation; 200/201/204.

```json
{"platform":"windows","provider":"wns","token":"channel-uri-or-device-token","accountId":"client-account-id"}
```

Platforms: android, ios, macos, windows. Providers: fcm, apns, wns. Store tokens
privately; validate provider/platform combinations and WNS URI host against
Microsoft's documented endpoints before sending. Support multiple recipients per
installation. Rotate token atomically, expire registrations by a renewable lease,
and remove invalid provider tokens. Never send stale recipient notifications
following logout. Rate-limit registration and inbox reads.

### DELETE /eisenvault/api/v1/notification-devices/{installationId}

Revoke only this recipient/installation association; 200/204, or 404 if absent.
Adapters must revoke before removing credentials; failed offline revocation needs
an explicit retry/lease policy. Revocation cannot retract an already delivered
notification, so retain generic lock-screen copy and revalidate taps.

`WorkflowNotificationApi` implements registration/revocation requests for future
native push adapters. These methods are not currently wired to auth lifecycle
because no provider token/channel adapter is configured.

## Work remaining for real remote push

1. Implement the workflow outbox, inbox and registration API on the server.
2. Configure FCM for Android and APNs for iOS/macOS (or FCM with APNs credentials).
   Add signing entitlements/provisioning, register device tokens, handle token
   rotation and auth registration/revocation, foreground messages, background
   display and cold-start tap routing. Generic alert payloads must display via OS
   when suspended; data-only delivery cannot guarantee a visible alert.
3. Implement a Windows WNS channel adapter in the native runner and deploy the
   required Windows application identity/Azure registration. Renew channels and
   route toast activation. A local Windows toast plugin does not receive WNS.
4. Connect foreground delivery to `WorkflowNotificationService.receive`, and
   route remote launch payloads through the same validated account/task handling.
   Avoid duplicate OS alerts when a provider already displayed the notification.
5. Implement Angora task navigation and provider-specific integration tests.

See [FCM Flutter setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[FCM message handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[Windows push overview](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/push-notifications/)
and [native local notification setup](https://github.com/MaikuB/flutter_local_notifications).

## Acceptance checks before enabling production

Verify initial assignment, custom signature steps, group tasks, reassignment,
duplicate events, token rotation, two accounts/servers with overlapping task IDs,
logout/offline revocation, expired sessions, denied permissions, terminated app
and cold-start taps on actual Android/iOS/macOS/Windows devices. Build Windows
as MSIX using the existing identity; test release Android resource shrinking.
The Dart API tests cover auth headers, URL prefix/cursor encoding, cross-account
rejection, malformed pages, expired auth and idempotent registration/revocation.
Actual OS display and remote push have not been verified by these tests.
