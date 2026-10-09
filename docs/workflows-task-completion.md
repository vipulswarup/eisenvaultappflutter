# Standard task completion

Implemented and tested on 9 October 2026 against the supplied demo Alfresco 5.2 server.

## Supported actions

Completion of the built-in `activiti$activitiAdhoc` workflow's `wf:adhocTask` and `wf:completedAdhocTask`, using the server's visible `Next` transition and its label. Other workflow types remain read-only. In particular, signature approval, approval/rejection, claim/release and reassignment are not enabled by this increment.

The app reads metadata through POST `s/api/formdefinitions` with `itemKind: task`, and submits to the task's local `s/api/task/{id}/formprocessor` endpoint. No arbitrary server-provided submission URL is followed.

The current control matrix covers mandatory non-repeating text and integer fields, LIST choices, LENGTH limits and MINMAX ranges, plus current comments. Protected fields remain server-controlled. An existing standard assignee is preserved; unsupported mandatory controls or constraints block completion with an explanation. Optional custom fields are omitted. This increment does not yet provide user/group pickers or editable date controls.

The task and form are fetched again immediately before submission. A changed snapshot or lost eligibility clears the draft and refreshes the form. Mutations are never automatically retried. An uncertain response disables resubmission until refresh. Alfresco revalidates permissions and values; the preflight check does not make the operation atomic.

## Drafts

Form values are stored with the signed-in account ID, task ID and a fingerprint of task/form state. Account IDs already include the server identity. Matching drafts restore on reopening and app restart. Changed tasks discard saved values. Successful completion deletes the draft; sign-out removes the account's drafts.

## Validation

- The existing fixture preview builds and runs on macOS.
- A live check through the actual Dart service loaded a dedicated test document and task form, completed the task, confirmed its completed state and absence from My Tasks.
- A native macOS integration test created its own document/workflow, opened the task in the rendered Flutter UI, checked document names, entered a comment, clicked Task Done and verified the list and draft cleanup. Test fixtures were removed afterwards.
- Unit/widget tests cover field constraints, mandatory-control blocking, protected workflow types, direct/pooled pagination, account-scoped drafts, reopening, successful completion and concurrent changes.
- Credentials were supplied temporarily outside the repository. No credentials are included in committed code or test fixtures.

## Repeat the native test

Create a private JSON file outside the repository containing `WORKFLOW_TEST_URL` (including `/alfresco`), `WORKFLOW_TEST_USER` and `WORKFLOW_TEST_PASSWORD`. Run:

```
flutter test --no-pub -d macos integration_test/workflow_completion_test.dart --dart-define-from-file=/absolute/path/to/private-test-config.json
```

The configured account must be able to search its person node and create/remove test documents and workflows. This is an opt-in test for a disposable test environment; it is not included in the normal unit suite. Remove the configuration file after testing and rebuild the normal app to replace the test executable.

For a dedicated existing test task, `dart run tool/workflow_live_check.dart <alfresco-url> <task-id> [--complete]` reads username/password from stdin. Completion is restricted to workflows whose message begins `Codex workflow completion test`.

## Next

Standard review approve/reject actions are covered in [the next increment](workflows-review-actions.md). Group claim/release and broader form support remain next. Signature transitions must remain disabled until signing/versioning recovery is implemented and tested.
