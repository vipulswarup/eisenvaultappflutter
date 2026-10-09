# Standard review actions

The built-in single-review workflow (`activiti$activitiReview`, task type
`wf:activitiReviewTask`) now exposes Approve and Reject buttons. Both submit
the server's visible `Next` transition with the corresponding
`prop_wf_reviewOutcome` value. Reject requires confirmation; cancelling leaves
the task unchanged. Comments follow server metadata, including optional comments
on the default Alfresco 5.2 review form.

The app validates the outcome property, allowed choices and transition before
enabling actions. Unknown review outcomes, protected outcome controls and other
workflow types remain unavailable. Signature tasks remain read-only.

The existing task/form preflight and account-scoped drafts apply to review tasks.
After submission, the service checks the completed task state and recorded
outcome. An uncertain result is not retried automatically.

Unit and widget tests cover decision payloads, mandatory comments, unsupported
metadata, cancellation, stale state and outcome verification. The native test in
`integration_test/workflow_completion_test.dart` creates separate completion,
approval and rejection fixtures and checks the rendered macOS UI and server
result. See [test configuration instructions](workflows-task-completion.md#repeat-the-native-test).

Group task claim/release is covered in [the next increment](workflows-group-ownership.md). Next: workflow initiation and broader workflow form support.
Signature approval needs its signing/version recovery flow before enabling it.

## Follow-up acknowledgement and document previews

Built-in single and pooled review workflows now support `wf:approvedTask` and
`wf:rejectedTask` follow-up notifications. Their Acknowledge button submits the
server's validated `Next` transition without a new approval/rejection outcome.
Existing form constraints, ownership checks, draft persistence and completion
verification apply. Custom and parallel workflow task types remain unavailable.

Workflow document rows retain the package document IDs and open through the same
`FileTapHandler`, document download service and type-specific viewers used by
folder browsing. Preview routes are pushed above task details, so Back returns
to that workflow. Folder/search callers retain their existing offline support
and navigation. Workflow previews download with the current account credentials.

Validation: approved/rejected form rules were inspected on the Alfresco 5.2 test
server; acknowledgement payloads have regression coverage. The native macOS
preview test downloads a text document from a local fixture server, verifies
its content, then checks Back returns to the same workflow. The full 67-test
suite and focused analysis pass.

## EisenVault Document Approval

The deployed `activiti$docApproveReject` / `scwf:activitiReviewTask` pair
supports Approve and Reject through `Next`, writing
`prop_scwf_approveRejectOutcome`. The adapter validates the exact outcome field,
its data key, editable text/list metadata, allowed decisions, and the task's
outcome-property reference. Accepted references are `scwf:approveRejectOutcome`
and `{http://www.jkl.com/model/workflow/1.0}approveRejectOutcome`; surrounding
whitespace is ignored when matching the reference. Other workflow/task pairs,
including signature and permission-request tasks, are not enabled by this adapter.
Required controls/comments, rejection confirmation, drafts, preflight refresh,
and post-completion outcome verification use the existing review logic.
Optional custom comments remain omitted under the initial-release requirements.

Alfresco 5.2 emits literal newlines/tabs in this custom model's QName defaults
inside JSON strings. Only formdefinitions responses escape string control
characters before decoding, preserving their contents. Other JSON syntax errors
still fail. This does not change the workflow model on the server.

Validation: all 70 normal tests pass; focused analysis is clean. The opt-in
`integration_test/document_approval_test.dart` passed three native macOS checks:
loading the deployed form and cancelling rejection without mutation; approving
a disposable review task; and confirming rejection on a second disposable task.
Both decisions completed through the UI, and the task API recorded the expected
`scwf_approveRejectOutcome`. Existing user tasks were not modified.

Document Approval derives its reviewer sequence from the workflow context folder's
`scwf:userSelect` aspect and `scwf:userName` property. Generic starts without that
context produced no review task. Live fixtures used a dedicated folder with
`scwf:userName: admin`, one test document, and an explicit `prop_bpm_context` on
the start request. This establishes the task action path; starting this custom
workflow from the app remains unsupported pending context/assignment integration.
Both workflows and the folder/document were removed after testing.

The native test takes private `WORKFLOW_TEST_URL` and `WORKFLOW_TEST_AUTH` dart
defines for an admin account with an existing Document Approval task. Its optional
mutation checks additionally require `WORKFLOW_CUSTOM_APPROVE_TASK`,
`WORKFLOW_CUSTOM_REJECT_TASK`, and `WORKFLOW_CUSTOM_NODE`. Each mutation fixture
must have workflow description `Codex approval validation` and exactly the
specified document, whose name starts with `Codex approval validation`. Use
fresh, disposable tasks. The form-display test uses a mutation-blocking client.
Delete private configuration and rebuild the regular app after testing.
