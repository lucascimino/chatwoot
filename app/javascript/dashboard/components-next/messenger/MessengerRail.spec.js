import { mount, flushPromises } from '@vue/test-utils';
import { createRouter, createMemoryHistory } from 'vue-router';
import { ref } from 'vue';
import MessengerRail from './MessengerRail.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(1) }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key =>
    ref(
      key.includes('Unread')
        ? () => 0
        : [
            { id: 10, name: 'Pessoal' },
            { id: 20, name: 'Empresa' },
          ]
    ),
}));
vi.mock('dashboard/components-next/sidebar/SidebarAccountSwitcher.vue', () => ({
  default: { template: '<div />' },
}));

describe('Messenger inbox navigation', () => {
  it('clears the conversation route when switching by click or shortcut', async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        {
          path: '/:accountId/inbox/:inbox_id/:conversation_id?',
          name: 'inbox_dashboard',
          component: { template: '<div />' },
        },
        {
          path: '/:accountId/search',
          name: 'search',
          component: { template: '<div />' },
        },
        {
          path: '/:accountId/settings',
          name: 'settings_inbox_list',
          component: { template: '<div />' },
        },
      ],
    });
    await router.push('/1/inbox/10/99');
    const wrapper = mount(MessengerRail, { global: { plugins: [router] } });
    await wrapper.get('button[aria-label="Empresa"]').trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.params.inbox_id).toBe('20');
    expect(router.currentRoute.value.params.conversation_id).toBeUndefined();
    window.dispatchEvent(
      new KeyboardEvent('keydown', { key: '1', metaKey: true })
    );
    await flushPromises();
    expect(router.currentRoute.value.params.inbox_id).toBe('10');
    window.dispatchEvent(
      new KeyboardEvent('keydown', {
        key: 'ArrowLeft',
        metaKey: true,
        altKey: true,
      })
    );
    await flushPromises();
    expect(router.currentRoute.value.params.inbox_id).toBe('20');
    wrapper.unmount();
  });
});
