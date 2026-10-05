# Workflow first increment

Implemented: read-only Workflows → My Tasks for Classic/Alfresco accounts.

- Requests active tasks for the authenticated user, including eligible pooled tasks, through `/alfresco/s/api/task-instances`.
- Fetches all pages, removes duplicate/completed entries, and sorts by task due date; undated tasks come last, ties use task ID.
- Opens refreshed details and rechecks current eligibility to handle reassignment. Missing/completed tasks show an unavailable message.
- Displays workflow type, initiator, current comments, and document names from the workflow package, where supplied.
- Dates display in device local time; overdue means strictly before now, due soon means within 24 hours inclusive.
- No persisted task cache or cross-account aggregation. No task mutations, notifications, unread state, or document opening in this increment.

## Emulator preview without a server

`flutter emulators --launch Medium_Phone_API_36.0`

`flutter run -d emulator-5554 -t tool/workflow_preview.dart`

The separate preview entrypoint uses clearly labelled fixture data. Production `lib/main.dart` always uses the authenticated Alfresco service.

## Live acceptance check

Sign into an Alfresco account and open Workflows from the browse drawer. Create direct and pooled tasks in Share. Check list visibility, ordering, details and document names; then complete or reassign a task in Share and refresh. Switch accounts through the browse drawer and verify their lists remain separate. Disconnect networking and exercise Retry.

Automated tests cover parsing/timezones, due-date boundaries, ordering, authenticated pagination, duplicate/completed filtering, missing tasks, expired sessions, document names, list/detail rendering and error/retry states.

Live Alfresco 5.2 compatibility remains to be validated against a reachable test server. API investigation used Alfresco's repository web-script descriptors:
https://github.com/Alfresco/alfresco-remote-api/blob/master/src/main/resources/alfresco/templates/webscripts/org/alfresco/repository/workflow/task-instances.get.desc.xml
https://github.com/Alfresco/alfresco-remote-api/blob/master/src/main/resources/alfresco/templates/webscripts/org/alfresco/repository/workflow/task-instance.get.desc.xml

Android emulator verification required raising compileSdk from 36 to 37 for the existing permission_handler_android dependency. targetSdk and minSdk remain unchanged.
