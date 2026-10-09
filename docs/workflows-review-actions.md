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

Next: group task claim/release, followed by broader workflow form support.
Signature approval needs its signing/version recovery flow before enabling it.
