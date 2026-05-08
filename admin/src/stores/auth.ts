import { create } from 'zustand';

interface User {
  id: string;
  phone: string;
  nickname: string;
  role: string;
  avatar?: string;
}

interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  login: (accessToken: string, refreshToken: string, user: User) => void;
  logout: () => void;
  setUser: (user: User) => void;
}

function isTokenValid(): boolean {
  const token = localStorage.getItem('access_token');
  return !!token && token !== 'undefined' && token !== 'null';
}

export const useAuthStore = create<AuthState>((set) => ({
  isAuthenticated: isTokenValid(),
  user: null,
  login: (accessToken, refreshToken, user) => {
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
    set({ isAuthenticated: true, user });
  },
  logout: () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    set({ isAuthenticated: false, user: null });
  },
  setUser: (user) => set({ user }),
}));
