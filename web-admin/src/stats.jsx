import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { api } from './api';

export const POLL_MS = 20000;
const StatsContext = createContext({ stats: null, refresh: () => {} });

/** The dashboard numbers (and the sidebar badges), refreshed every 20 s and after every action. */
export function StatsProvider({ children }) {
  const [stats, setStats] = useState(null);
  const [error, setError] = useState(null);
  const [tick, setTick] = useState(0); // bumps on every refresh so pages can reload too
  const alive = useRef(true);

  const refresh = useCallback(async () => {
    try {
      const s = await api.get('/admin/stats');
      if (alive.current) {
        setStats(s);
        setError(null);
        setTick((t) => t + 1);
      }
    } catch (e) {
      if (alive.current) setError(e.message);
    }
  }, []);

  useEffect(() => {
    alive.current = true;
    refresh();
    const id = setInterval(refresh, POLL_MS);
    return () => {
      alive.current = false;
      clearInterval(id);
    };
  }, [refresh]);

  return <StatsContext.Provider value={{ stats, error, refresh, tick }}>{children}</StatsContext.Provider>;
}

export const useStats = () => useContext(StatsContext);
