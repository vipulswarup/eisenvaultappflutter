# Group task ownership

Task details show Claim task or Release task using Alfresco's current
`isClaimable` / `isReleasable` flags. Release requires confirmation. Ownership
changes refresh the details and form, and disable other actions while pending.
Standard pooled review (`activiti$activitiReviewPooled`,
`wf:activitiReviewTask`) supports Approve / Reject after claiming.

Alfresco keeps `isPooled: true` on a claimed group task. The app uses the actual
owner and eligibility flags rather than treating all pooled tasks as unassigned.

The service checks current visibility, state, owner and eligibility before
writing. It uses `PUT api/-default-/public/workflow/versions/1/tasks/{numericId}`
with `select=state` and `state: claimed` / `unclaimed`. The select parameter is
required on Alfresco 5.2: without it, a successful response does not change state.
Claim uses Alfresco's atomic claim operation; an already-owned task returns a
conflict. Release is restricted in the client to the authenticated owner.
The service reads the task again to confirm the resulting owner. Mutations are
never automatically retried. Uncertain responses require a refresh.

Task/form changes invalidate existing drafts through the existing fingerprint
check. Release does not complete a task or select a review outcome. Unsupported
workflow forms, including signature approval, remain unavailable after claiming.

Sources: [Alfresco claim implementation](https://github.com/Alfresco/alfresco-remote-api/blob/master/src/main/java/org/alfresco/rest/workflow/api/impl/TasksImpl.java),
[Share task ownership controls](https://github.com/Alfresco/share/blob/develop/share/src/main/webapp/components/workflow/task-edit-header.js).

The opt-in macOS test `integration_test/workflow_ownership_test.dart` expects a
dedicated disposable pooled-review fixture and a private configuration file with
`WORKFLOW_TEST_URL`, `WORKFLOW_TEST_AUTH`, `WORKFLOW_TEST_TASK_ID`, and
`WORKFLOW_TEST_COMPETITOR`. AUTH is a ticket authorization header. The test uses
admin to simulate competing ownership on its dedicated fixture, checks the
native UI claim/release flow, and verifies a server conflict. Do not point it at
ordinary user tasks. Remove private configuration and rebuild the normal app
after testing.

Validation on the supplied Alfresco 5.2 server: the native macOS test passed
claim, review-action unlocking, release cancellation, confirmed release,
stale-owner rejection and an HTTP 409 for an already-owned task. Unit tests
cover payload restrictions, ownership verification and no retries after
uncertain responses. All 58 normal tests pass; focused analysis is clean.
Dedicated workflow, group and person fixtures were removed afterwards.
Newly created test users returned HTTP 401 on login, so a two-session test
with non-admin group members remains unverified. Competing ownership was
simulated by assigning the dedicated task to a test person through admin.
