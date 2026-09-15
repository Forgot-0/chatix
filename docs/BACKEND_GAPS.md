# Backend gaps

Things the Flutter client does that the API (`api-docs.md`, checked against
`main` 2026-09-15) has nowhere to keep. Each one works today, on the device
that did it, and silently does not follow the account anywhere else.

The point of this file is that none of these are client bugs to be fixed in
the client. They are fields and endpoints the backend does not have yet.

## Closed since the last pass

The API grew the per-user chat state this file used to ask for, and the
client now uses it. Kept here as a record of what moved, not as work:

| What | Where it lives now |
|---|---|
| Pinned chats, and the five-pin limit | `ChatDTO.is_pinned` / `pinned_at`, `PATCH /chats/{id}/state/`, `400 PINNED_CHATS_LIMIT_EXCEEDED` |
| The archive | `ChatDTO.is_archived`, and `GET /chats/?archived=true` as a set of its own |
| Silenced notifications | `ChatDTO.notifications_muted_until` / `is_muted_by_me` |
| Who to draw on a row | `ChatDTO.peer` for direct chats, `members_preview` for groups |
| Searching messages | `GET /chats/messages/search/`, cursor over message ids |
| Searching people in one field | `GET /profiles/?q=`, matching username OR display name |

On the client: `features/chat/presentation/providers/chat_state_actions.dart`
writes all three through one endpoint and moves the row while the request is
in flight; `features/chat_organizer` kept folders and gave up everything
else; `chat_flags.pinned`, `chat_flags.archived` and `chat_flags.muted` are
no longer read or written, and stale copies in shared preferences are simply
ignored.

⚠️ Nothing migrates what those keys held. A device that had pinned five chats
before this version starts from whatever the server says, which for an
account that has never pinned anything is nothing.

The message search kept its local half as an offline fallback rather than
deleting it: `OfflineFallbackMessageSearchRepository` asks the server, and
only when that request could not be made at all — no network, a timeout —
searches what this device has loaded and says so on screen. A rate limit or
a validation error is shown, not papered over.

---

## 1. Folders (П-5)

**What the client does.** `features/chat_organizer` keeps two things in
shared preferences:

| What | Storage key | Shape |
|---|---|---|
| Folders | `chat_organizer.folders` | JSON array of folders, each a list of rules |
| Organizer settings | `chat_organizer.settings` | `{unarchive_on_new_message, folders_hidden}` |

**Why it is not on the server.** There is no folder resource in the API.
Pins, the archive and the notification mute used to be in this list and are
not any more — see "Closed" above.

**What the user loses.** Reinstalling, switching phone, or signing in on the
web starts with the tab strip empty and the list unsorted. The note on the
folders screen (`organizerDeviceOnly`) is what says so.

**What the backend would need.**

- A folder resource: `GET/POST/PATCH/DELETE /chats/folders/` holding
  `{id, title, icon_key, match_mode, order, rules[]}` where a rule is
  `{type, ...}` with the five types the client already writes
  (`chat_type`, `unread`, `pinned`, `no_reply_from_me`, `member`). The client
  model (`data/models/folder_rule_model.dart`) is a flat record with a `type`
  discriminator and drops rule types it does not recognise, so the server can
  add types without breaking older builds.
- A per-user settings blob, or two booleans on the profile, for
  `unarchive_on_new_message` and `folders_hidden`.

**Client swap cost once it exists.** One file:
`data/datasources/chat_organizer_local_data_source.dart` gains a remote twin
behind the same interface, and
`presentation/providers/chat_organizer_providers.dart` points at it. The
repository, the use cases, the rules and every screen stay as they are — the
data source is already asynchronous for exactly this reason. That is the
trip pins and the archive already made.

**Unread counts per folder** are computed on the client from
`ChatDTO.unread_count` over the rows the list has loaded. With cursor
pagination that is "the pages fetched so far", not the whole account. A
server-side count per folder would be the honest number.

**The archive badge has the same shape of problem.** How much is in the
archive is now a second request (`GET /chats/?archived=true`), so the count
on the drawer is "what the first page of the archive holds", not the whole
archive. An `archived_count` / `archived_unread_count` on the list response
would let the drawer say the true number without fetching the set.

---

## 2. What the message search cannot reach (П-6)

The endpoint exists and the client uses it. Three limits are worth writing
down because they look like client bugs from the outside (api-docs §0.24,
§5.4.1):

- **Only `messages.content` is indexed.** Attachment file names, chat names
  and descriptions, and member names never match. A reader searching for a
  PDF by its name finds nothing, and nothing on screen explains why.
  `AttachmentDTO.file_name` in the index would fix the most common case.
- **No substring, no CJK.** The index is `simple` full-text: the last term
  matches by prefix and the rest exactly, so `юдже` does not find `бюджет`
  and a Japanese or Chinese query only matches where the text happens to be
  split the same way. A trigram index, or an ICU tokenizer for CJK, is the
  usual answer.
- **No ranking.** Results come back `id DESC`, newest first. For a query
  with one obvious answer deep in the history, that answer is on page four.
  `ts_rank` behind a `sort=relevance` would be enough.

The client compensates where it can: `MessageSearchTerms` repeats the
server's term rules so the snippet and the highlighting agree with what
matched, rather than looking for the query as one string and finding nothing.

---

## 3. Search history is local (П-6)

Recent queries (`search.recent_queries`) and recently opened chats
(`search.recent_chats`) are kept in shared preferences. Nothing in the API
stores either, and a list of things someone typed is not something to upload
on their behalf without asking. Worth a server-side home only if the product
wants search history to follow the account.

---

## 4. Drafts are on the server but not in the client yet (П-4)

`ChatDTO.draft` and `PATCH /chats/{id}/state/ {draft}` exist (api-docs §5.2),
and `UpdateChatStateUseCase.setDraft` already speaks to them. The UI does
not: `chat_drafts`, a JSON map of chat id to text in shared preferences, is
still what the composer reads and writes, so a draft typed on a phone is
still not there on the desktop.

This one is client work, not a backend gap. It needs a rule for which copy
wins when both have one — the server carries `draft_updated_at` for exactly
that — and a debounce, since the endpoint takes 60 writes a minute and a
composer produces more.

---

## 5. Member rules still match on partial knowledge (П-5)

The "includes a person" folder rule can only look at what a chat row carries.
That is more than it was: `ChatDTO.peer` names the other person in every
direct chat, and `members_preview` carries up to three members of a group.
Beyond those three, a group's roster is only known to a screen that has
fetched it.

A folder like "chats with Ann" is therefore right about direct chats, right
about small groups, and blind to a large group Ann is quietly a member of.
A `member_ids` on the row, or server-side folder evaluation (gap 1), would
close it.
