/* global axios */
import { useIntervalFn } from '@vueuse/core';
import { watch, onBeforeUnmount } from 'vue';
import types from 'dashboard/store/mutation-types';

export function mergeSourceMessages(existing, incoming) {
  const merged = new Map(existing.map(message => [message.id, message]));
  incoming.forEach(message => {
    const requestId = message.content_attributes?.desk_request_id;
    if (requestId) {
      existing
        .filter(item => item.echo_id === requestId)
        .forEach(item => merged.delete(item.id));
    }
    merged.set(message.id, message);
  });
  return [...merged.values()].sort((a, b) => a.created_at - b.created_at);
}

export function useSourcePolling(store, route, inboxes) {
  let active;
  let generation = 0;
  const reset = () => {
    generation += 1;
    active?.abort();
  };
  watch(() => route.fullPath, reset);
  onBeforeUnmount(reset);
  useIntervalFn(async () => {
    if (
      active ||
      document.hidden ||
      !inboxes.value.some(inbox => inbox.desk_source)
    )
      return;
    const version = generation;
    const account = route.params.accountId;
    const conversationId = Number(route.params.conversation_id);
    const controller = new AbortController();
    active = controller;
    try {
      if (conversationId) {
        const { data } = await axios.get(
          `/api/v1/accounts/${account}/conversations/${conversationId}/messages`,
          { signal: controller.signal }
        );
        if (version !== generation) return;
        const chat = store.getters.getSelectedChat;
        if (chat?.id !== conversationId) return;
        store.commit(types.SET_MISSING_MESSAGES, {
          id: conversationId,
          data: mergeSourceMessages(chat.messages, data.payload),
        });
      } else {
        const { data } = await axios.get(
          `/api/v1/accounts/${account}/conversations`,
          {
            params: {
              inbox_id: route.params.inbox_id,
              status: 'all',
              assignee_type: 'all',
            },
            signal: controller.signal,
          }
        );
        if (version !== generation) return;
        data.data.payload.forEach(conversation => {
          store.commit(types.ADD_CONVERSATION, conversation);
          store.commit(types.UPDATE_CONVERSATION, conversation);
        });
      }
    } catch (error) {
      // The next tick retries reads; mutations are never retried by this poller.
    } finally {
      active = null;
    }
  }, 5000);
}
