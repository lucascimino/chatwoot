export const messengerEnabled =
  import.meta.env.VITE_DESK_LAYOUT === 'messenger' &&
  (!import.meta.env.VITE_DESK_HOST ||
    window.location.hostname === import.meta.env.VITE_DESK_HOST);
export const messengerRoutes = new Set([
  'home',
  'inbox_dashboard',
  'inbox_conversation',
  'conversation_through_inbox',
]);
