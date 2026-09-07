import { mount } from '@vue/test-utils';
import { reactive, ref, nextTick } from 'vue';
import { useSourcePolling, mergeSourceMessages } from './useSourcePolling';

const timers = vi.hoisted(() => ({ tick: null }));
vi.mock('@vueuse/core', () => ({
  useIntervalFn: callback => {
    timers.tick = callback;
  },
}));

it('discards responses after switching accounts and does not overlap requests', async () => {
  let resolve;
  const get = vi.fn(
    () =>
      new Promise(done => {
        resolve = done;
      })
  );
  vi.stubGlobal('axios', { get });
  const route = reactive({ fullPath: '/accounts/2', params: { accountId: 2 } });
  const store = { commit: vi.fn() };
  const wrapper = mount({
    setup() {
      useSourcePolling(store, route, ref([{ desk_source: true }]));
      return {};
    },
    template: '<div />',
  });
  const pending = timers.tick();
  await timers.tick();
  expect(get).toHaveBeenCalledTimes(1);
  route.fullPath = '/accounts/1';
  route.params.accountId = 1;
  await nextTick();
  resolve({ data: { data: { payload: [{ id: 10 }] } } });
  await pending;
  expect(store.commit).not.toHaveBeenCalled();
  wrapper.unmount();
  vi.unstubAllGlobals();
});

it('replaces a pending send and merges repeated remote updates without duplicate bubbles', () => {
  const pending = { id: 'temp', echo_id: 'request', created_at: 2 };
  const older = { id: 1, created_at: 1 };
  const accepted = {
    id: 2,
    created_at: 2,
    content_attributes: { desk_request_id: 'request' },
  };
  const first = mergeSourceMessages([older, pending], [accepted]);
  expect(first).toEqual([older, accepted]);
  expect(mergeSourceMessages(first, [accepted])).toEqual(first);
});
