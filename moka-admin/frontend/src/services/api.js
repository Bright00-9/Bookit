import axios from 'axios';

const api = axios.create({ baseURL: '/admin' });

// Attach JWT token to every request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('moka_admin_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Redirect to login on 401
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('moka_admin_token');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  },
);

// Auth
export const login = (email, password) =>
  api.post('/auth/login', { email, password });
export const getMe = () => api.get('/auth/me');

// Users
export const getUsers = (params) => api.get('/users', { params });
export const getUser = (id) => api.get(`/users/${id}`);
export const suspendUser = (id) => api.patch(`/users/${id}/suspend`);
export const unsuspendUser = (id) => api.patch(`/users/${id}/unsuspend`);
export const deleteUser = (id) => api.delete(`/users/${id}`);

// Jobs
export const getJobs = (params) => api.get('/jobs', { params });
export const getJob = (id) => api.get(`/jobs/${id}`);
export const updateJobStatus = (id, status) =>
  api.patch(`/jobs/${id}/status`, { status });
export const deleteJob = (id) => api.delete(`/jobs/${id}`);

// Analytics
export const getOverview = () => api.get('/analytics/overview');
export const getJobsBySkill = () => api.get('/analytics/jobs-by-skill');
export const getJobsOverTime = (days) =>
  api.get('/analytics/jobs-over-time', { params: { days } });
export const getUsersOverTime = (days) =>
  api.get('/analytics/users-over-time', { params: { days } });
export const getTopWorkers = () => api.get('/analytics/top-workers');
