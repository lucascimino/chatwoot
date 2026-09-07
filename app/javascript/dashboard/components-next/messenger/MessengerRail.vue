<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useEventListener } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import SidebarAccountSwitcher from 'dashboard/components-next/sidebar/SidebarAccountSwitcher.vue';
import { useAccount } from 'dashboard/composables/useAccount';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountId } = useAccount();
const inboxes = useMapGetter('inboxes/getInboxes');
const unread = useMapGetter('conversationUnreadCounts/getInboxUnreadCount');
const orderedInboxes = computed(() =>
  [...inboxes.value].sort((a, b) => a.id - b.id)
);
const selectedId = computed(() => Number(route.params.inbox_id));
function selectInbox(inbox) {
  router.push({
    name: 'inbox_dashboard',
    params: { accountId: accountId.value, inbox_id: inbox.id },
  });
}
useEventListener(window, 'keydown', event => {
  if (!event.metaKey || event.shiftKey || event.isComposing) return;
  let index = Number(event.key) - 1;
  if (event.altKey && ['ArrowLeft', 'ArrowRight'].includes(event.key)) {
    const current = orderedInboxes.value.findIndex(
      inbox => inbox.id === selectedId.value
    );
    index =
      (current +
        (event.key === 'ArrowRight' ? 1 : -1) +
        orderedInboxes.value.length) %
      orderedInboxes.value.length;
  } else if (event.altKey || !/^[1-9]$/.test(event.key)) return;
  const inbox = orderedInboxes.value[index];
  if (inbox) {
    event.preventDefault();
    selectInbox(inbox);
  }
});
</script>

<template>
  <nav
    class="flex flex-col items-center gap-3 w-16 shrink-0 h-full overflow-y-auto py-4 border-e border-n-weak bg-n-slate-2"
    :aria-label="t('SIDEBAR.INBOXES')"
  >
    <div class="size-11 shrink-0"><SidebarAccountSwitcher is-collapsed /></div>
    <button
      v-for="(inbox, index) in orderedInboxes"
      :key="inbox.id"
      class="relative size-11 shrink-0 rounded-full grid place-items-center text-xs font-semibold border-2 focus-visible:ring-2 focus-visible:ring-n-teal-8"
      :class="
        inbox.id === selectedId
          ? 'border-n-teal-9 bg-n-teal-3 text-n-teal-12'
          : 'border-transparent bg-n-slate-4 text-n-slate-12 hover:bg-n-slate-5'
      "
      :aria-label="inbox.name"
      :aria-pressed="inbox.id === selectedId"
      :title="`${inbox.name}${index < 9 ? ` (⌘${index + 1})` : ''}`"
      @click="selectInbox(inbox)"
    >
      <img
        v-if="inbox.avatar_url"
        :src="inbox.avatar_url"
        alt=""
        class="size-full rounded-full object-cover"
      />
      <span v-else>{{ inbox.name.slice(0, 2).toUpperCase() }}</span>
      <span
        v-if="unread(inbox.id)"
        class="absolute -end-1 -bottom-1 rounded-full bg-n-teal-9 text-white text-[0.625rem] px-1 min-w-4"
        >{{ unread(inbox.id) }}</span
      >
    </button>
    <RouterLink
      :to="{ name: 'search', params: { accountId } }"
      class="mt-auto grid place-items-center size-10 shrink-0 text-n-slate-11 rounded-lg hover:bg-n-slate-4"
      :aria-label="t('COMBOBOX.SEARCH_PLACEHOLDER')"
    >
      <span class="i-lucide-search size-5" />
    </RouterLink>
    <RouterLink
      :to="{ name: 'settings_inbox_list', params: { accountId } }"
      class="grid place-items-center size-10 shrink-0 text-n-slate-11 rounded-lg hover:bg-n-slate-4"
      :aria-label="t('SIDEBAR.SETTINGS')"
    >
      <span class="i-lucide-settings size-5" />
    </RouterLink>
  </nav>
</template>
