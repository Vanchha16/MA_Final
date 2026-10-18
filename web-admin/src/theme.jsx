import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { Icon } from './components/ui';

const KEY = 'aws_admin_theme';
const ThemeContext = createContext({ mode: 'system', resolved: 'light', setMode: () => {} });

const read = () => {
  try { return localStorage.getItem(KEY) || 'system'; } catch { return 'system'; }
};
const systemDark = () => window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false;

/** Light, Dark or System (follows the computer), remembered in this browser. */
export function ThemeProvider({ children }) {
  const [mode, setModeState] = useState(read);
  const [sysDark, setSysDark] = useState(systemDark);

  useEffect(() => {
    const mq = window.matchMedia?.('(prefers-color-scheme: dark)');
    if (!mq) return undefined;
    const onChange = (e) => setSysDark(e.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  const resolved = mode === 'system' ? (sysDark ? 'dark' : 'light') : mode;
  useEffect(() => {
    const root = document.documentElement;
    root.classList.toggle('dark', resolved === 'dark');
  }, [resolved]);

  const value = useMemo(() => ({
    mode,
    resolved,
    setMode: (m) => {
      const root = document.documentElement;
      root.classList.add('theme-fade');
      setTimeout(() => root.classList.remove('theme-fade'), 300);
      setModeState(m);
      try { localStorage.setItem(KEY, m); } catch { /* private mode */ }
    },
  }), [mode, resolved]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export const useTheme = () => useContext(ThemeContext);

/** Three-way switch: Light / Dark / System. */
export function ThemeSwitch({ className = '' }) {
  const { mode, setMode } = useTheme();
  return (
    <div role="radiogroup" aria-label="Theme" className={`flex rounded-full bg-soft p-1 ${className}`}>
      {[['light', 'light_mode', 'Light'], ['dark', 'dark_mode', 'Dark'], ['system', 'contrast', 'System']].map(([m, icon, label]) => (
        <button
          key={m}
          type="button"
          role="radio"
          aria-checked={mode === m}
          title={label}
          onClick={() => setMode(m)}
          data-testid={`theme-${m}`}
          className={`flex flex-1 items-center justify-center gap-1 rounded-full py-1.5 text-[12px] font-semibold transition-colors ${
            mode === m ? 'bg-card text-brand shadow-card' : 'text-muted hover:text-ink'
          }`}
        >
          <Icon name={icon} size={16} />{label}
        </button>
      ))}
    </div>
  );
}
