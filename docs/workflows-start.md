# Start a workflow from one document

The document action menu offers Start workflow for online Classic / Alfresco
accounts. Choose a server workflow definition and complete its start form.
The first increment supports built-in New Task (`activiti$activitiAdhoc`) and
Review and Approve (`activiti$activitiReview`). Permission-request definitions
are excluded. Other definitions show an unavailable explanation.

The form includes a single assignee, description, priority, optional due date,
current comment, and compatible mandatory text/integer controls. Required custom
controls that cannot be represented block submission. Notification options retain
server defaults. Assignee associations must target one `cm:person`; group and
multiple-assignee start forms remain for a later increment. Only the selected
document is included; folders and multiple documents are not supported.

User search checks up to 25 name matches. It excludes disabled users and checks
the document's direct/inherited ACL against known read-capable roles and group
memberships where these are visible to the initiating account. Applicable denies
and unknown grants are handled conservatively. When other-user membership cannot
be inspected, direct grants can still qualify unless an unknown group deny could
apply. When the account cannot view the document ACL, only self is selectable,
after checking content access using a streamed request that is immediately
cancelled without downloading the document. These restrictions can omit users
who have access through custom permissions or private groups.

Submission refreshes the definition/version, document and form, rechecks the
assignee's access and enabled state, resolves its person node, and then sends
one formprocessor request. Definition names address Alfresco 5.2's start-form
endpoints; versioned definition IDs detect deployment changes before submission.
The result is read back and its package must contain exactly the selected
document. Permissions can still change between preflight and submission; client
checks are not an atomic server authorization check for the assignee.

Drafts are scoped by account, server, document and definition. Changed metadata
discards ordinary saved values. Successful creation clears the draft. A pending
attempt is saved before mutation and retained after an uncertain result,
including across app restart or metadata changes. It blocks another submission
of that saved attempt. Failed preflight checks are distinguished from an uncertain
mutation. Automatic reconciliation/unlocking of uncertain starts is deferred;
check the server before initiating another workflow.

Validation uses dedicated documents with Collaborator and Consumer grants.
The native macOS test starts both workflows as a non-admin collaborator, checks
receipt and document names as a read-only consumer, and completes the tasks.
It also checks consumer self-selection and refusal after a consumer grant is
revoked. Unit/widget coverage includes typed payloads, required controls, ACL
filtering and protection against duplicate submission after app restart.

The opt-in native test `integration_test/workflow_start_test.dart` takes a private
dart-define JSON file outside the repository, containing `WORKFLOW_TEST_URL`,
admin `WORKFLOW_TEST_USER` / `WORKFLOW_TEST_PASSWORD`,
`WORKFLOW_REVIEWER_USER` / `WORKFLOW_REVIEWER_PASSWORD`,
`WORKFLOW_CONSUMER_USER` / `WORKFLOW_CONSUMER_PASSWORD`, and
`WORKFLOW_TEST_NODE_ID` / `WORKFLOW_TEST_NODE_NAME` for a dedicated disposable
document whose name starts with `Codex workflow start test`. The reviewer needs
Collaborator access and the consumer needs Consumer access. The test removes
its workflows and restores fixture permissions. Remove the document afterwards,
delete the private configuration, and rebuild the normal macOS app.
