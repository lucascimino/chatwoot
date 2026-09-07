describe('Messenger hostname selection', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it.each([
    ['messenger', 'chat.lucascimino.com', 'chat.lucascimino.com', true],
    ['messenger', 'chat.lucascimino.com', 'chat.lkskrs.online', false],
    [
      'messenger',
      'chat.lucascimino.com',
      'chat.lucascimino.com.example.test',
      false,
    ],
    ['messenger', '', 'localhost', true],
    ['', 'chat.lucascimino.com', 'chat.lucascimino.com', false],
  ])(
    'selects layout %s on host %s / %s',
    async (layout, host, current, expected) => {
      vi.stubEnv('VITE_DESK_LAYOUT', layout);
      vi.stubEnv('VITE_DESK_HOST', host);
      vi.stubGlobal('window', { location: { hostname: current } });
      const { messengerEnabled } = await import('./messenger');
      expect(messengerEnabled).toBe(expected);
    }
  );
});
