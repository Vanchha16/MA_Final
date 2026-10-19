import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, ApiError, setSignedOutHandler, tokenStore } from './api';

const AuthContext = createContext(null);

/** Who is signed in. Staff and admin accounts get in; customers see an error. */
const TEAM = ['staff', 'admin'];

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
      .then((me) => (TEAM.includes(me.role) ? setUser(me) : logout('This account is not shop staff.')))
      .catch(() => logout())
      .finally(() => setReady(true));
  }, [logout]);

  const login = useCallback(async (email, password) => {
    const data = await api.post('/auth/login', { email, password });
    if (!TEAM.includes(data.user.role)) throw new ApiError('This account is not shop staff. Use the mobile app to shop.', 403);
    tokenStore.set(data.token);
    setNotice(null);
    setUser(data.user);
  }, []);

  // The owner: staff, promo codes and blocking customers
  const isAdmin = user?.role === 'admin';
  const value = useMemo(() => ({ user, isAdmin, ready, login, logout, notice }), [user, isAdmin, ready, login, logout, notice]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
