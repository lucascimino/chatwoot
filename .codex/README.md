# Messenger preview

Fork based on Chatwoot Community v4.17.1. Build with `VITE_DESK_LAYOUT=messenger` to enable the compact inbox rail, native account switcher, Command+1..9 and Command+Option+arrows. Without the flag the standard UI remains available.

Use the upstream Ruby version and pnpm 10. `VITE_DESK_LAYOUT=messenger pnpm exec vite build` builds the actual dashboard. `pnpm exec vitest run app/javascript/dashboard/components-next/messenger/MessengerRail.spec.js` verifies inbox switching clears the selected conversation.

A development-only fixture script `.codex/seed-messenger-preview.rb` requires a fresh local database named `chatwoot_messenger_preview`, an ephemeral password via `MESSENGER_PREVIEW_PASSWORD`, and creates API inboxes with no webhook. No Evolution credentials or existing Chatwoot database are used. These are synthetic conversations, not imported WhatsApp history.

Full deployment uses the upstream Rails/Sidekiq/PostgreSQL/Redis services. Do not point Rails migrations at the Desk database. Before production cutover, validate the Evolution bridge, participant attribution in groups, recovered history, media, send confirmation and permissions. The existing Node application stays published until that acceptance.
