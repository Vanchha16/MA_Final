import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, ApiError, setSignedOutHandler, tokenStore } from './api';

const AuthContext = createContext(null);

/** Who is signed in. Only admin accounts get in; anyone else sees an error. */
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [ready, setReady] = useState(false);
  const [notice, setNotice] = useState(null);

  const logout = useCallback((message = null) => {
    tokenStore.set(null);
    setUser(null);
    setNotice(message);
  }, []);

  useEffect(() => {
    setSignedOutHandler((message) => logout(message || 'Please log in again.'));
    if (!tokenStore.get()) {
      setReady(true);
      return;
    }
    api.get('/auth/me')
      .then((me) => (me.role === 'admin' ? setUser(me) : logout('This account is not a shop admin.')))
      .catch(() => logout())
      .finally(() => setReady(true));
  }, [logout]);

  const login = useCallback(async (email, password) => {
    const data = await api.post('/auth/login', { email, password });
    if (data.user.role !== 'admin') throw new ApiError('This account is not a shop admin. Use the mobile app to shop.', 403);
    tokenStore.set(data.token);
    setNotice(null);
    setUser(data.user);
  }, []);

  const value = useMemo(() => ({ user, ready, login, logout, notice }), [user, ready, login, logout, notice]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
