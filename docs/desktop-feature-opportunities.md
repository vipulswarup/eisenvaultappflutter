# Desktop feature opportunities

This document proposes features that could make EisenVault Desktop more useful on Windows and macOS. The groups are organized by the primary user need each feature serves; each proposal appears once.

## 1. Find and review content

Help users locate and understand documents inside EisenVault.

- **Fast search and preview** — Search by filename, metadata, and supported document text. Show useful filters and previews so users can identify the right result before opening it.
- **Desktop document viewer** — Provide reliable PDF and office-document viewing with page navigation, zoom, thumbnails, and annotations. Make it clear when a document must open in another application.
- **Compare versions** — Let users inspect two versions side by side and see what changed, especially for PDFs and supported office formats.

## 2. Create, edit, and organize content

Make routine document changes and multi-file work efficient from the desktop.

- **Open, edit, and save back** — Open a document in its default desktop application and return the saved version to EisenVault, with clear status and conflict handling.
- **Batch file operations** — Select multiple documents to move, download, tag, or submit for approval in one action.
- **Capture and upload from anywhere** — Support drag and drop, clipboard image upload, and a tray or menu-bar drop target for quick uploads.

## 3. Work across tasks and people

Bring work that involves assignments, decisions, and other users into the desktop workflow.

- **Task-focused home screen** — Surface assigned tasks, pending approvals, recent documents, and pinned workspaces in one customizable starting view.
- **Actionable notifications** — Notify users about assignments, approvals, mentions, and completed uploads, with an action to open the relevant item.
- **Controlled sharing** — Create links with expiration and access limits, and show who can access each shared document.

## 4. Keep files available and consistent

Support work when the network is unavailable or unreliable, and explain how local and server copies relate.

- **Offline files and folders** — Let users choose content for offline access and show which items are available locally.
- **Queued changes and sync status** — Queue supported edits and uploads while offline, then synchronize when connectivity returns. Show progress, failures, and the last successful sync.
- **Conflict resolution** — Detect concurrent edits and guide users through keeping a version, comparing versions, or saving both copies. Never silently discard a change.

## 5. Fit the operating system and user needs

Make the app feel natural and usable across Windows and macOS.

- **Native file-manager actions** — Add Finder and File Explorer actions such as “Open in EisenVault” and “Save to EisenVault,” plus operating-system drag and drop.
- **Keyboard and accessibility support** — Provide discoverable shortcuts, screen-reader labels, keyboard navigation, and high-contrast support.
- **Responsive desktop layout** — Adapt gracefully to different window sizes, display scaling, and larger text while keeping primary actions easy to reach.

## Suggested delivery order

1. **File-manager actions and edit-back flow** — Reduce friction in the common cycle of finding, editing, and returning a file.
2. **Task-focused home screen and actionable notifications** — Make assigned work visible and easier to complete.
3. **Search and document preview improvements** — Shorten the time it takes to find and verify the right document.
4. **Offline access and synchronization** — Add substantial value for mobile or unreliable-network work, with conflict handling designed as part of the feature.
5. **Batch actions, sharing controls, and viewer enhancements** — Expand efficiency and review capabilities based on usage feedback.

The order is a starting point for product discussion. Offline sync depends on explicit rules for which files may be stored locally, how local data is protected, and how conflicts are resolved.
