import axios from 'axios';

export const catalogApi = axios.create({
  baseURL: import.meta.env.VITE_CATALOG_API || 'http://localhost:8001',
});

export const userApi = axios.create({
  baseURL: import.meta.env.VITE_USER_API || 'http://localhost:8002',
});

export const orderApi = axios.create({
  baseURL: import.meta.env.VITE_ORDER_API || 'http://localhost:8003',
});

function attachAuthInterceptor(instance) {
  instance.interceptors.request.use((config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  });
}

attachAuthInterceptor(catalogApi);
attachAuthInterceptor(userApi);
attachAuthInterceptor(orderApi);
