import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Token will be set by AuthContext after login

export const scenarioAPI = {
  list: () => api.get('/api/v1/scenarios/'),
  get: (id) => api.get(`/api/v1/scenarios/${id}`),
  create: (data) => api.post('/api/v1/scenarios/', data),
  update: (id, data) => api.put(`/api/v1/scenarios/${id}`, data),
  delete: (id) => api.delete(`/api/v1/scenarios/${id}`),
  import: (file) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post('/api/v1/scenarios/import', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
};

export const experimentAPI = {
  create: (data) => api.post('/api/v1/sessions/experiments', data),
};

export const sessionAPI = {
  create: (data) => api.post('/api/v1/sessions/', data),
  getNextScenario: (sessionId) => api.get(`/api/v1/sessions/${sessionId}/next-scenario`),
  submitResponse: (sessionId, scenarioId, data) => 
    api.post(`/api/v1/sessions/${sessionId}/responses`, data, {
      params: { scenario_id: scenarioId }
    }),
  exportJSONL: (sessionId) => 
    api.get(`/api/v1/sessions/${sessionId}/export/jsonl`, {
      responseType: 'blob'
    }),
};

export default api;
