# Workflow requirements — initial release

Status: requirements draft based on user decisions. My Tasks, standard New Task completion, single-review approve/reject, Document Approval task actions, approved/rejected acknowledgement, workflow document previews, group claim/release and starting standard workflows from a document are implemented; see workflows-first-increment.md, workflows-task-completion.md, workflows-review-actions.md, workflows-group-ownership.md and workflows-start.md for coverage and validation.
Date: 5 October 2026.

## Goal and scope

Allow users to start document workflows, receive assignment and lifecycle notifications, and act on their tasks in the Flutter app on iOS, macOS, Windows, Android, and Linux.

- Initially support Alfresco Content Services 5.2's built-in workflow engine. Standalone Alfresco Process Services is out of scope.
- Support all deployed workflow definitions, including custom workflows and **request signature**, subject to form compatibility below.
- Exclude **request permission / seek permission** workflows. Resolve their server definition identifiers during implementation rather than relying only on display names.
- Available to all users with the necessary Alfresco permissions; no additional app-role or subscription restriction.
- Include tasks from workflows started in any client, including Alfresco Share.
- Alfresco remains authoritative for permissions, task state, validation, assignment, and permitted transitions.

## Starting a workflow

1. The user selects a document and invokes the workflow action.
2. The app retrieves available server workflow definitions, excluding permission-request workflows.
3. The user selects a workflow and completes its server-defined start form.
4. The app validates and submits online, then confirms the result.

Only the selected document is included. Starting from folders, the Workflows area, or multiple documents is out of scope.

### Forms and compatibility

- Support workflow-defined assignees, dates, and comments, including user/group selection and multiple selection where the definition permits it.
- Show mandatory custom fields on both start and task forms. Do not expose optional custom fields in this release.
- Follow Alfresco defaults for required comments, including rejection comments; do not impose additional requirements.
- If a mandatory field needs an unsupported custom control, show the workflow or task as unavailable with a clear explanation and prevent submission. Do not offer an Alfresco Share fallback.
- This replaces the earlier decision to hide workflows with additional mandatory fields.
- Required-field rules, allowed values, and action-specific validation must follow the server definition; a workflow cannot be submitted with required fields omitted.

### Assignees

- Individual users must have at least view access to the document to be selectable.
- A group may be selected if at least some members have view access or above.
- Preserve the selected group as the assignee and retain default Alfresco group behavior; do not expand it into a modified list of members.
- Apply the same access restrictions to reassignment, where Alfresco permits it.
- Server permissions must be revalidated when submitting; a filtered picker is not authorization.

## Workflows area

- Provide a separate Workflows area containing **My Tasks** only: active tasks assigned directly to the user or available through their groups.
- Keep lists separate for each signed-in account/server. No combined cross-account list.
- Sort by due date, with overdue tasks first. Placement of tasks without due dates and tie-breaking remain implementation decisions.
- Show new/unread indicators and a navigation count. Opening a task clears its new/unread indicator. The precise count semantics remain to be defined.
- No search or filters in the initial release.
- Do not show completed/cancelled history or earlier workflow comments and completed steps; history remains available through the web UI.
- Tracking and cancelling workflows started by the user are deferred, superseding earlier decisions to include them.

### Task details and actions

Show the document name, workflow type, initiator, due date, current comments, and available actions, where supplied by Alfresco. Current form comments are distinct from a historical comment feed.

- Support all actions offered by the workflow, including approve, reject, complete, claim, release, and reassign, when permitted and compatible with the form.
- Group tasks follow Alfresco's claim/release behavior.
- Ask for confirmation before rejection or completing a signature. Ordinary approvals and other actions submit directly.
- Refresh task state before submission and handle server rejection if the task changes concurrently.
- Require connectivity for all workflow mutations, including starting, claiming, releasing, signing, and submitting. Do not queue offline actions.
- If a task has been completed or reassigned, refresh the view and explain why the requested action is unavailable.

### Document viewing and saved forms

- Provide an option to open the document on a separate screen and return to the workflow form.
- Preserve entered values and comments during this navigation, when leaving the Workflows area, and across app closure.
- Associate drafts with their account, server, task or workflow definition, and document to prevent cross-account reuse.
- On return, refresh the task. If it has changed, discard saved entries and show the refreshed state. Detecting relevant changes requires technical validation.
- Delete account-specific drafts on sign-out.
- Document version-history viewing was not separately confirmed and is not an initial-release requirement.

### Due-date presentation

| State | Appearance |
| --- | --- |
| Overdue | Red plus a text status |
| Due within 24 hours | Amber plus a text status |
| Other | Normal appearance |

Use text alongside colour so status does not rely on colour alone. Due-date timezone interpretation and boundary behavior must be consistent between the UI and reminders.

## Request signature

Reuse the existing signing service and Flutter signing action. Existing integration points include `lib/services/signing/ess_signing_service.dart` and `lib/screens/signing/signing_webview_screen.dart`; their suitability for workflow integration needs validation.

1. Confirm the signing action with the user.
2. Invoke the existing signing flow for the task's document.
3. Verify that the signature has been inserted and the signed document has been versioned.
4. Treat this as approval and submit the workflow's corresponding transition to its next step.

- Do not advance the workflow before signing and versioning succeed.
- If signing/versioning succeeds but the workflow transition fails, retain the task as pending and offer **retry approval without signing again**.
- Persist sufficient account/task/document-version/signing-session evidence to recover that partial success, including after app restart. Validate recovery against current server state.
- Failed or cancelled signing must not approve the task.
- Do not assume signing/versioning and workflow progression form one atomic operation. Validate safe retries and uncertain-response recovery to avoid duplicate signatures or transitions.

## Notifications

### Events and recipients

| Event | Behavior |
| --- | --- |
| New assignment | Notify the assigned user; for a group task notify every eligible group member when it becomes available |
| Claimed group task | Subsequent task reminders go only to the claimant |
| Workflow completion | Notify recipients according to the workflow's default Alfresco behavior |
| Approval/rejection outcome | Notify recipients according to the workflow's default Alfresco behavior |
| Approaching deadline | One reminder 24 hours before the due date |
| Overdue | One notification when the task becomes overdue; no daily repeats |

- Notify for all signed-in accounts even when another account is selected.
- Show task/document names in notification content; rely on OS privacy settings to hide previews when configured.
- Tapping a notification opens its specific task or workflow in the correct account context, with sign-in first when necessary.
- Since My Tasks excludes history, an expired or completed target must have a graceful current-state message; it must not introduce a history screen.
- On first sign-in, populate existing tasks without a backlog of assignment pushes. Subsequent assignments generate notifications.
- Stop account notifications on sign-out until sign-in resumes; remove that account's notification registration and hosted polling authorization.
- Deduplicate detected events and reminders. The app and hosted service must not both notify for the same detected event.

### Publicly reachable servers

Recommended architecture, pending technical validation:

- Use an EisenVault-hosted notification service to poll existing Alfresco APIs and dispatch platform notifications.
- Do not require a new component installed on Alfresco.
- The user accepts delayed notifications rather than requiring near-instant delivery. A roughly two-minute polling target was discussed; exact interval and delivery guarantees are not finalized.
- The user permits securely protected authentication tokens for each signed-in account to be stored by the hosted service for checks while the app is closed.
- Design account-isolated token storage, expiration/reauthentication handling, and sign-out revocation. Do not log tokens.
- Secure network reachability and usable account authorization are prerequisites; internet reachability alone does not establish authorization.

### Private/on-premise servers

- Initial-release limitation accepted: no closed-app notifications when the hosted service cannot reach the server.
- While the app is open and connected to the server, periodically check for new tasks and show local assignment notifications.
- A customer-installed relay or other secure connectivity arrangement is optional future scope, not required for this release.
- Surface the notification capability for each account clearly so users understand this limitation.

### Platform requirement

Closed-app push notifications are desired on iOS, macOS, Windows, Android, and Linux for reachable servers. Each platform requires a feasibility check and suitable delivery integration. Do not assume a single push provider covers all five or that OS termination, force-stop, and app closure have identical semantics.

Linux closed-app delivery is a specific unresolved feasibility item. The private-network limitation does not waive the desired closed-app support for reachable Linux accounts. If a platform requires a resident process or installation changes, document that constraint and obtain a product decision before narrowing the requirement.

## Technical validation before implementation commitments

1. Identify the Alfresco 5.2 endpoints and permissions for definitions, forms, active tasks, group eligibility, claiming/releasing, reassignment, and transitions.
2. Determine how server form metadata exposes mandatory fields, conditional/action-specific requirements, and custom controls. Build a supported-control matrix.
3. Validate document-access checks for users and groups without silently changing Alfresco assignment semantics.
4. Identify the signature workflow and its approval transition by definition, and verify signing/version completion and recovery evidence.
5. Validate authenticated hosted polling, token lifetimes, multi-account isolation, and removal on sign-out.
6. Determine how polling can detect completion/outcomes and reproduce workflow-defined notification recipients without exposing an in-app history view. A disappearing active task alone does not prove completion or rejection.
7. Establish desktop/mobile delivery support, deep links, OS permissions, registration lifecycle, and closed-app behavior for every platform.
8. Define due-date timezone handling, missing due dates, unread-count semantics, changed-task detection, reminder behavior after due-date edits, and polling intervals. These have not been explicitly decided.

## Suggested implementation sequence

1. Validate workflow API/form coverage and notification feasibility; record any constraints requiring further product decisions.
2. Implement account-specific My Tasks, task details, document navigation, drafts, and online actions.
3. Implement document-only starts, dynamic mandatory forms, access-filtered assignment, and group claim/release.
4. Integrate signature approval with durable recovery of partial success.
5. Add hosted polling, foreground private-server checks, event deduplication, reminders, and platform delivery/deep links.
6. Validate against representative standard and custom workflows on Alfresco 5.2 and each target OS.

## Acceptance scenarios

- A permitted user starts a supported workflow on one document; no folder or additional document is offered.
- Permission-request workflows are excluded; request signature is available when compatible.
- Mandatory custom fields appear on start and task forms; unsupported mandatory controls block submission with an explanation. Optional custom fields are omitted.
- A user without view access cannot be selected; a partially eligible group remains a group assignee.
- Direct and group tasks appear under the correct account, in due-date order, with colour and text status.
- Claim/release and reassignment follow server permissions; concurrent changes refresh the task instead of submitting stale actions silently.
- Document navigation and app restart preserve form entries; a changed task discards them after refresh.
- Signing/versioning success advances the workflow. A failed transition can be retried without signing again, including after restart.
- New assignments from any client notify the correct accounts; initial sign-in does not generate assignment backlog pushes.
- Completion/outcome recipients follow the workflow default. Group reminders go to the claimant after claim; deadline and overdue notifications do not repeat unexpectedly.
- Tapping a notification opens the correct account/task or provides an appropriate unavailable/completed-state message.
- Private accounts receive local assignment notifications while open and connected; their closed-app limitation is visible.
- Sign-out deletes drafts and disables further account notifications and polling authorization.
- No started-by-me tracking, cancellation, workflow history, search/filtering, or queued offline mutations appears in this release.

## Reference material

These references support architectural investigation; they do not establish that every requirement is already supported.

- [Alfresco Content Services 5.2 REST API guide](https://docs.hyland.com/r/Alfresco/Alfresco-Content-Services/5.2/Alfresco-Content-Services/Alfresco-Content-Services/Develop/ReST-API-Guide?contentId=PXh2zJrgUAfmJo2hPE0JZQ)
- [Alfresco 5.2 workflow documentation source](https://github.com/Alfresco/docs-alfresco/blob/master/content-services/5.2/admin/workflows.md)
- [Firebase Cloud Messaging architecture and trusted sender environment](https://firebase.google.com/docs/cloud-messaging/)
