export const messengerEnabled =
  import.meta.env.VITE_DESK_LAYOUT === 'messenger';
export const messengerRoutes = new Set([
  'home',
  'inbox_dashboard',
  'inbox_conversation',
  'conversation_through_inbox',
]);
