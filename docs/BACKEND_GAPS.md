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

---

## 6. A chat has no avatar anyone can set 🔴

`ChatDTO.avatar_s3_key` and `ChatDetailDTO.avatar_s3_key` are readable and
nothing else. There is no chat equivalent of the profile avatar flow from
api-docs §4.5:

| What exists for a profile | What exists for a chat |
|---|---|
| `POST /profiles/{id}/avatar/presign/` → presigned PUT | — |
| `avatar_s3_key` written by the confirm step | `avatar_s3_key` is read-only |
| `avatars` matrix of sizes/formats on the DTO | not present |
| `avatar_url`, presigned, 300 s TTL | not present |

`UpdateChatRequest` (api-docs §5.2) takes `name`, `description`, `is_public`,
`admin_only`, `slow_mode_seconds` and `permissions` — no avatar field — so
even a key uploaded some other way could not be attached to the chat.

**What the client does.** Nothing: the chat profile screen has no way to
change a picture, because there is no button that could work. A group draws
the mosaic of its members' faces (`members_preview`, or the roster when the
screen has one) and falls back to its initial on its own colour;
`avatar_s3_key` is carried through the model and never resolved, since there
is no endpoint that turns a key into a URL either.

**What it needs.** The §4.5 pair, scoped to a chat and gated on
`chat:update`: a presign endpoint, a confirm that writes `avatar_s3_key`, and
a presigned `avatar_url` on `ChatDTO` / `ChatDetailDTO` with the same 300 s
TTL as every other avatar — cached by `s3_key`, never by the URL.

---

## 7. No shared-media index for a chat 🔴

There is no `GET /chats/{chat_id}/media/`, no `?has_attachments=` filter on
`GET /chats/{chat_id}/messages/`, and no attachment collection of any kind.
Attachments exist only inside the message that carried them (api-docs §5.4,
§5.5), and the only way to enumerate them is to walk the message history.

**What the client does.** The chat profile's Media / Files / Links / Voice
tabs are built on the device, from two overlapping views of the same
history: the window the chat screen has loaded, and the 200 messages the
local cache keeps per chat
(`presentation/utils/chat_shared_content.dart`,
`presentation/providers/chat_profile_provider.dart`). Links are not a server
concept at all — they are found by running message text through the same
parser the bubbles use.

**What the user loses.** The tabs are as deep as this device's history and no
deeper. A photo sent last year is not in them until someone scrolls back far
enough in the chat for it to be, and a fresh install starts with all four
tabs empty. Every tab says so in a line under the list
(`sharedContentLocalOnly`), rather than passing off a partial answer as a
complete one.

**What it needs.** Either a media endpoint with its own cursor
(`GET /chats/{chat_id}/attachments/?type=image|video|file|voice`) or a
`has_attachments` / `attachment_type` filter on the message list. Either one
also removes the reason `MediaViewerScreen` has to fall back to fetching a
single message when the viewer is opened outside the loaded window.

---

## 8. Public chats have no invite link of their own 🔴

`POST /chats/{chat_id}/join/` lets any signed-in user into a chat with
`is_public: true` (api-docs §5.2), but nothing mints a way to hand that chat
to somebody: no invite token, no public slug or `@handle` for a chat, no
revocable link, no landing page. `is_public` is the whole of the access
model.

**What the client does.** Composes `https://<origin>/chats/<chat_id>` from
the configured server origin and the chat id
(`presentation/utils/chat_invite_link.dart`), shows it on the profile of a
public chat, and copies it to the clipboard.

**What the user loses.** The link only means something to someone who
already has ChatiX and is signed in — there is no web page behind it, and
following it from a browser does nothing. It also cannot be revoked,
expired, or limited to a number of uses, because it is not a token: it is
the chat's id, which never changes. Turning `is_public` off is the only way
to close the door, and it closes it for every link at once.

**What it needs.** An invite resource — `POST /chats/{chat_id}/invites/`
returning a token with an optional expiry and use count, `DELETE` to revoke,
and a join-by-token endpoint — plus, for links to be worth sending to people
who do not have the app, a web landing page on the same origin and
associated-domain / app-link records so the app claims the URL.

---

## 9. `member:mute` is a permission with nothing behind it 🔴

The chat role matrix gives `member:mute` to owner and admin (api-docs §8.1),
`MemberChatDTO` and `MemberDetailDTO` both report `is_muted`, and the
composer already reads it: a muted member sees `composerMuted` instead of a
text field. What is missing is the endpoint that sets it. The members router
has exactly four writes (api-docs §5.3):

| What | Endpoint |
|---|---|
| Add | `POST /chats/{chat_id}/members/` |
| Change role | `PATCH /chats/{chat_id}/members/{user_id}/role/` |
| Ban / unban | `PATCH /chats/{chat_id}/members/{user_id}/ban/` |
| Kick | `DELETE /chats/{chat_id}/members/{user_id}/` |

There is no `.../mute/` among them. `POST /chats/{chat_id}/calls/participants/{user_id}/mute/`
is a different thing entirely — it silences a microphone in a LiveKit room
(`call:mute_member`), not a member's right to post.

**What the client does.** Nothing, deliberately. `ChatMemberAction`
(`presentation/utils/chat_member_actions.dart`) has no `mute` case, so the
member list's action sheet never offers one — a button that cannot send a
request is worse than no button. The state is still shown: a muted member
wears a `Muted` badge in the list, and the permission itself is honoured
everywhere it is read.

**What the user loses.** A moderator can only ban or remove someone. There is
no middle step between "may post" and "is out of the chat", which is the
usual answer to one bad afternoon.

**What the backend would need.** `PATCH /chats/{chat_id}/members/{user_id}/mute/`
shaped like the ban endpoint — `{reason?: string, muted_to?: datetime}` with
the same three readings of the date (null forever, future temporary, past
lifts it) — plus a `member_muted` WS event carrying
`{target_user_id, requester_id, mute}` so the other clients and the
composer's `is_muted` update without a refetch.

**Client swap cost once it exists.** A `MuteMemberUseCase` beside
`BanMemberUseCase`, one method on `ChatMembersController`, and two entries in
`ChatMemberAction` (`mute`, `unmute`) — the permission check
(`hasChatPermission(chat, me, ChatPermissions.memberMute)`) and the badge are
already written.

---

## 10. A profile cannot say who it belongs to 🔴

`ProfileDTO` (api-docs §4.3) carries `id`, `avatars`, `specialization`,
`display_name`, `bio`, `date_birthday`, `skills` and `links`. It does not
carry `username` — and `GET /profiles/{id}/` is the only endpoint that
returns a profile on its own. Meanwhile the same person's handle is right
there in every *other* shape the API has for them: `ChatProfileDTO.username`
in a chat's member list (§5.3), `ContactProfileDTO.username` in the address
book (§4.7). Even `GET /profiles/?q=` searches by username without ever
returning one.

**What the client does.** `ProfileScreen` shows `@handle` when it has one and
omits the line when it does not. Its own profile takes the handle from
`GET /users/me/` (`authProvider`); somebody else's arrives as
`?username=` on `ProfileDetailRoute`, passed along by the screen the profile
was opened from — the member list and the `@mention` in a message both know
it. Opened any other way — a deep link, a share link, a push — the handle is
simply not shown. Nothing is guessed and nothing extra is fetched: finding a
handle by id would mean paging `GET /profiles/` or `GET /contacts/` and
matching, at 20 requests a minute.

**What the user loses.** The one identifier that is stable, typeable and
unique is missing from the screen built to identify a person. Display names
are optional and not unique, so a profile with no display name falls back to
"Unknown profile" for somebody who has a perfectly good `@handle`.

**What the backend would need.** One field: `username: string` on
`ProfileDTO`. It is already denormalised into two other DTOs, so the data is
at hand.

**Client swap cost once it exists.** `ProfileModel` gains the field,
`ProfileEntity` carries it, `ProfileScreen` reads `profile.username` instead
of `widget.username`, and `ProfileDetailRoute`'s `?username=` query parameter
and the two call sites that fill it are deleted.

---

## 11. Sharing a profile is passing a string around 🔴

Same shape as the chat invite link in §8, and the same cause. There is no
public identity for a profile: no slug, no shareable URL, and
`GET /profiles/{id}/` needs a token (§4.2 closed the list too). So there is
nothing to hand somebody that opens anywhere.

**What the client does.** `ProfileShareLink` composes
`https://<host>/profiles/<id>` from the configured origin and copies it to
the clipboard, with the name and handle above it when they are known. Inside
the app the link routes correctly; outside it, it is a 404.

**What the user loses.** "Share profile" reaches people who already have
ChatiX and are signed in. Sending one to anybody else does nothing.

**What the backend would need.** The same landing-page work §8 asks for — a
web page on the origin that renders a public sliver of a profile and deep
links into the app — plus a stable public handle to address it by (see §10).

---

## 12. An avatar upload is never confirmed or refused 🔴

`POST /profiles/avatar/upload_complete/` answers `200` and queues a
background task. That task decides the real MIME type (`python-magic`, by
content) and checks the 5 MB cap, and when it refuses the file it raises
`AVATAR_NOT_TYPE_IMAGE` or `AVATAR_SIZE` — into a worker, where no client
can see them (api-docs §2.5, §4.5). There is no status endpoint and no WS
event; chat attachments get `attachment_success` (§6.4), avatars get
nothing.

**What the client does.** Everything it can before uploading: the picture is
decoded, cropped and re-encoded on the device
(`presentation/utils/avatar_image.dart`), which both guarantees it really is
an image and keeps it inside the cap. After `upload_complete` it polls
`GET /profiles/my/` for about ten seconds
(`AvatarUploadController._awaitProcessing`) and calls the upload failed if
`avatars` never changes, offering the same picture back for a retry.

**What the user loses.** Up to ten seconds of waiting on a success, and a
failure message that cannot say *why* — "the server did not accept that
picture" is the whole of what the API makes knowable.

**What the backend would need.** Either an `avatar_success` / `avatar_failed`
WS event carrying the resulting `avatars` map or the error code, or a
`GET /profiles/avatar/status/{file_key}/` to poll deliberately instead of
watching a field for movement.

**Client swap cost once it exists.** `_awaitProcessing` is replaced by one
`await` on the event; the poll schedule, `AvatarPollSchedule`, and
`AvatarProcessingFailure`'s "we waited and nothing happened" meaning all go
away.
