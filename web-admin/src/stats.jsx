import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { api } from './api';
import { connectRealtime } from './realtime';

// Changes arrive over the socket at once; this slow check only covers a dropped connection.
export const POLL_MS = 60000;
const StatsContext = createContext({ stats: null, refresh: () => {} });

/** The dashboard numbers (and the sidebar badges), refreshed as soon as the server pushes a change
 * (Socket.IO, see realtime.js), after every action, and every 60 s as a fallback. */
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
    const disconnect = connectRealtime(refresh);
    return () => {
      alive.current = false;
      clearInterval(id);
      disconnect();
    };
  }, [refresh]);

  return <StatsContext.Provider value={{ stats, error, refresh, tick }}>{children}</StatsContext.Provider>;
}

export const useStats = () => useContext(StatsContext);
