# Backend gaps

Things the Flutter client does that the API (`api-docs.md`, checked against
`main` 2026-08-14) has nowhere to keep. Each one works today, on the device
that did it, and silently does not follow the account anywhere else.

The point of this file is that none of these are client bugs to be fixed in
the client. They are fields and endpoints the backend does not have yet.

---

## 1. Pinned chats, the archive and folders (П-5)

**What the client does.** `features/chat_organizer` keeps three things in
shared preferences:

| What | Storage key | Shape |
|---|---|---|
| Pinned chats (max 5) | `chat_flags.pinned` | list of chat ids, pin order |
| Archived chats | `chat_flags.archived` | list of chat ids |
| Folders | `chat_organizer.folders` | JSON array of folders, each a list of rules |
| Organizer settings | `chat_organizer.settings` | `{unarchive_on_new_message, folders_hidden}` |

**Why it is not on the server.** `ChatDTO` (api-docs §5.2) has no pin,
archive or folder field, and `MemberChatDTO.is_muted` is the moderator mute
from the `member:mute` right (api-docs §8.1) — it stops a member writing and
says nothing about how this device shows the chat.

**What the user loses.** Reinstalling, switching phone, or signing in on the
web starts from an unsorted list. Nothing warns them beyond the note on the
folders screen (`organizerDeviceOnly`).

**What the backend would need.**

- Per-user, per-chat flags on the chat list response, e.g.
  `ChatDTO.is_pinned`, `ChatDTO.is_archived`, `ChatDTO.pin_order`, plus
  `PATCH /chats/{chat_id}/state/` to set them. Pinning is per account, not
  per chat, so the write has to be scoped to the caller.
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
data source is already asynchronous for exactly this reason.

**Unread counts per folder** are computed on the client from
`ChatDTO.unread_count` over the rows the list has loaded. With cursor
pagination that is "the pages fetched so far", not the whole account. A
server-side count per folder would be the honest number.

---

## 2. No message search (П-6)

**What the client does.** The search screen's messages tab reads
`features/chat/data/repositories/local_message_search_repository.dart`, which
looks through `MessageCacheStore` — the messages this device has already
loaded. That cache is filled from two places:

- every chat row's `last_message` (api-docs §5.2), so the newest message of
  every chat is searchable from a cold start;
- everything a chat screen has pulled while it was open, which
  `ChatDetailController` files as the window changes.

It is capped (300 messages per chat, 40 chats) and lives in memory only.

**Why it is not on the server.** There is no search route. api-docs §5.4
lists every message endpoint: list, context, get, send, edit, delete,
forward, read. None of them takes a query.

**What the user sees.** A notice above the results saying the search covered
the loaded history, and the same sentence on the empty state. The client does
not pretend to have searched anything it has not.

**What the backend would need.** `GET /chats/messages/search/` with
`q`, optional `chat_id`, and the cursor pagination the other chat endpoints
use, returning `MessageDTO` plus enough of the chat to draw a result row.
Ranking and highlighting can stay on the client.

**Client swap cost once it exists.** One provider:
`messageSearchRepositoryProvider` in
`features/chat/presentation/providers/search_providers.dart` points at a
remote implementation of `MessageSearchRepository` instead of the local one.
Results carry their own `MessageSearchSource`, so the "loaded history" notice
disappears on its own and no widget changes. The in-chat search goes through
the same use case and follows automatically.

**Related:** the in-chat search only finds matches in that cache, but opening
one is a real request — `GET /chats/{id}/messages/context/?target_seq=`
(api-docs §5.4) — so a match found in a preview still opens at the right
place in history nobody has loaded.

---

## 3. People search has to ask twice (П-6)

`GET /profiles/` filters on `username` and `display_name` separately
(api-docs §4.2). The docs do not say how they combine when both are given,
and the obvious implementation ANDs them, which would mean searching for a
name returns only people whose username *and* display name both contain it.

So `PeopleSearchController` issues two requests per search, one per field,
and merges them by profile id. Both share one `CancelToken`, so a new
keystroke drops both.

A single `q` that ORs the fields — or a documented promise about how the two
combine — would halve the requests. Pagination is the awkward part of the
current shape: each field keeps its own page cursor, and `has_next` is the
union of the two.

---

## 4. Search history is local (П-6)

Recent queries (`search.recent_queries`) and recently opened chats
(`search.recent_chats`) are kept in shared preferences. Nothing in the API
stores either, and a list of things someone typed is not something to upload
on their behalf without asking. Worth a server-side home only if the product
wants search history to follow the account.

---

## 5. Muted chats (П-4)

`features/chat/data/datasources/chat_local_prefs_store.dart`, key
`chat_flags.muted`. Same story as above: there is no per-user notification
setting per chat in the API, and the moderator mute is a different thing.
Would need `ChatDTO.is_muted_by_me` plus a way to set it, and the push
service would have to honour it before sending.

---

## 6. Drafts (П-4)

`chat_drafts`, a JSON map of chat id to text. Never leaves the device. A
draft typed on a phone is not there on the desktop app. Would need a small
per-user key-value endpoint, or a `draft` field on the chat state resource
from gap 1.

---

## 7. Member rules match on partial knowledge (П-5)

The "includes a person" folder rule can only look at what a chat row carries:
the caller's own membership, a roster some screen happens to have loaded, the
author of `last_message`, and `created_by`. `GET /chats/` returns no members
(api-docs §5.2) and asking per chat would be one request per row.

A folder like "chats with Ann" is therefore right about the chats Ann has
spoken in recently and blind to the ones she has not. Either a
`members_preview` on `ChatDTO`, or server-side folder evaluation (gap 1),
would fix it properly.
