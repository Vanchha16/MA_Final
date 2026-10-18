import '@testing-library/jest-dom/vitest';

// Recharts measures its box; jsdom has no layout, so give it a size
class ResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
}
globalThis.ResizeObserver = ResizeObserver;

// Charts get a fixed size in tests (jsdom can't measure the page)
import { vi } from 'vitest';
import { cloneElement } from 'react';

vi.mock('recharts', async (importOriginal) => {
  const real = await importOriginal();
  return { ...real, ResponsiveContainer: ({ children }) => cloneElement(children, { width: 600, height: 180 }) };
});
