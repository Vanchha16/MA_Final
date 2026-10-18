import { act, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ThemeProvider, ThemeSwitch } from '../theme';

// A fake "prefers-color-scheme: dark" the test can flip
let systemDark = false;
const listeners = new Set();
beforeEach(() => {
  systemDark = false;
  listeners.clear();
  localStorage.clear();
  document.documentElement.className = '';
  window.matchMedia = (q) => ({
    media: q,
    get matches() { return systemDark; },
    addEventListener: (_, fn) => listeners.add(fn),
    removeEventListener: (_, fn) => listeners.delete(fn),
  });
});
const setSystem = (dark) => {
  systemDark = dark;
  act(() => listeners.forEach((fn) => fn({ matches: dark })));
};
const isDark = () => document.documentElement.classList.contains('dark');

test('the switch turns dark mode on and off and remembers it', async () => {
  const user = userEvent.setup();
  render(<ThemeProvider><ThemeSwitch /></ThemeProvider>);
  expect(isDark()).toBe(false);
  expect(screen.getByTestId('theme-system')).toHaveAttribute('aria-checked', 'true'); // default

  await user.click(screen.getByTestId('theme-dark'));
  expect(isDark()).toBe(true);
  expect(localStorage.getItem('aws_admin_theme')).toBe('dark');
  expect(screen.getByTestId('theme-dark')).toHaveAttribute('aria-checked', 'true');

  await user.click(screen.getByTestId('theme-light'));
  expect(isDark()).toBe(false);
  expect(localStorage.getItem('aws_admin_theme')).toBe('light');
});

test('a saved choice is used on the next visit', () => {
  localStorage.setItem('aws_admin_theme', 'dark');
  render(<ThemeProvider><ThemeSwitch /></ThemeProvider>);
  expect(isDark()).toBe(true);
});

test('System follows the computer, also when it changes', async () => {
  systemDark = true;
  render(<ThemeProvider><ThemeSwitch /></ThemeProvider>);
  expect(isDark()).toBe(true);
  setSystem(false);
  expect(isDark()).toBe(false);
  setSystem(true);
  expect(isDark()).toBe(true);

  // a fixed choice ignores the computer
  const user = userEvent.setup();
  await user.click(screen.getByTestId('theme-light'));
  setSystem(true);
  expect(isDark()).toBe(false);
});
