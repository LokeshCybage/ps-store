import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { userApi } from '../api';
import { decodeToken } from '../utils/token';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const stored = localStorage.getItem('token');
    if (stored) {
      const decoded = decodeToken(stored);
      if (decoded) {
        setToken(stored);
        setUser(decoded);
      } else {
        localStorage.removeItem('token');
      }
    }
    setLoading(false);
  }, []);

  const login = useCallback(async (username, password) => {
    const res = await userApi.post('/api/auth/login', { username, password });
    const { token: newToken } = res.data;
    localStorage.setItem('token', newToken);
    setToken(newToken);
    setUser(decodeToken(newToken));
    return res.data;
  }, []);

  const register = useCallback(async (username, email, password) => {
    const res = await userApi.post('/api/auth/register', { username, email, password });
    const { token: newToken } = res.data;
    localStorage.setItem('token', newToken);
    setToken(newToken);
    setUser(decodeToken(newToken));
    return res.data;
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem('token');
    setToken(null);
    setUser(null);
  }, []);

  const isAuthenticated = !!token;

  return (
    <AuthContext.Provider value={{ user, token, login, register, logout, isAuthenticated, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
