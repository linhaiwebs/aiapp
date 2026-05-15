import api from './request';

export const authApi = {
  login: (data: { phone: string; password: string }) =>
    api.post('/auth/login', data),
  smsLogin: (data: { phone: string; smsCode: string }) =>
    api.post('/auth/sms/login', data),
  sendSms: (data: { phone: string }) =>
    api.post('/auth/sms/send', data),
  getMe: () => api.get('/auth/me'),
  refreshToken: (refreshToken: string) =>
    api.post('/auth/refresh', { refreshToken }),
};

export const statsApi = {
  getStats: () => api.get('/admin/stats'),
  getTrends: () => api.get('/admin/stats/trends'),
};

export const projectApi = {
  list: (params?: any) => api.get('/projects', { params }),
  detail: (id: string) => api.get(`/projects/${id}`),
  create: (data: any) => api.post('/projects', data),
  update: (id: string, data: any) => api.patch(`/projects/${id}`, data),
  remove: (id: string) => api.delete(`/projects/${id}`),
  getTasks: (id: string, params?: any) => api.get(`/projects/${id}/tasks`, { params }),
  batchTasks: (id: string, data: any) => api.post(`/projects/${id}/tasks/batch`, data),
};

export const categoryApi = {
  list: (params?: any) => api.get('/categories', { params }),
  detail: (id: string) => api.get(`/categories/${id}`),
  create: (data: any) => api.post('/categories', data),
  update: (id: string, data: any) => api.patch(`/categories/${id}`, data),
  remove: (id: string) => api.delete(`/categories/${id}`),
};

export const taskApi = {
  list: (params?: any) => api.get('/tasks', { params }),
  detail: (id: string) => api.get(`/tasks/${id}`),
  create: (data: any) => api.post('/tasks', data),
  update: (id: string, data: any) => api.patch(`/tasks/${id}`, data),
  remove: (id: string) => api.delete(`/tasks/${id}`),
  pendingClaims: (params?: any) => api.get('/tasks/claims/pending', { params }),
  allClaims: (params?: any) => api.get('/tasks/claims/all', { params }),
  approvedClaims: (params?: any) => api.get('/tasks/claims/approved', { params }),
  approveClaim: (claimId: string) => api.post(`/tasks/claims/${claimId}/approve`),
  rejectClaim: (claimId: string, reason?: string) => api.post(`/tasks/claims/${claimId}/reject`, { reason }),
  clearAllData: () => api.delete('/tasks/data/all'),
  batchDelete: (ids: string[]) => api.post('/tasks/batch-delete', { ids }),
  batchUpdateStatus: (ids: string[], status: string) => api.post('/tasks/batch-status', { ids, status }),
  pendingReview: (params?: any) => api.get('/tasks/pending-review', { params }),
  review: (id: string, data: { action: 'approve' | 'reject'; projectId?: string; reason?: string }) =>
    api.post(`/tasks/${id}/review`, data),
};

export const userApi = {
  list: (params?: any) => api.get('/users', { params }),
  detail: (id: string) => api.get(`/users/${id}`),
  create: (data: any) => api.post('/users', data),
  invite: (data: any) => api.post('/users/invite', data),
  update: (id: string, data: any) => api.patch(`/users/${id}`, data),
  updateStatus: (id: string, status: string) =>
    api.patch(`/users/${id}/status`, { status }),
};

export const submissionApi = {
  all: (params?: any) => api.get('/submissions/all', { params }),
  pendingReview: (params?: any) =>
    api.get('/submissions/pending-review', { params }),
  detail: (id: string) => api.get(`/submissions/${id}`),
  approve: (id: string) => api.post(`/submissions/${id}/approve`),
  reject: (id: string, reason: string) =>
    api.post(`/submissions/${id}/reject`, { reason }),
  update: (id: string, data: any) => api.patch(`/submissions/admin/${id}`, data),
  remove: (id: string) => api.delete(`/submissions/admin/${id}`),
  batchDelete: (ids: string[]) => api.post('/submissions/batch-delete', { ids }),
};

export const teamApi = {
  list: (params?: any) => api.get('/teams', { params }),
  detail: (id: string) => api.get(`/teams/${id}`),
  create: (data: any) => api.post('/teams', data),
  update: (id: string, data: any) => api.patch(`/teams/${id}`, data),
  remove: (id: string) => api.delete(`/teams/${id}`),
  getMembers: (id: string) => api.get(`/teams/${id}/members`),
  addMember: (id: string, data: any) => api.post(`/teams/${id}/members`, data),
  removeMember: (id: string, memberId: string) =>
    api.delete(`/teams/${id}/members/${memberId}`),
  inviteMember: (id: string, data: any) =>
    api.post(`/teams/${id}/invite`, data),
  joinByCode: (joinCode: string) =>
    api.post('/teams/join', { joinCode }),
  pendingMembers: (teamId: string) =>
    api.get(`/teams/${teamId}/members/pending`),
  approveMember: (teamId: string, memberId: string) =>
    api.post(`/teams/${teamId}/members/${memberId}/approve`),
  rejectMember: (teamId: string, memberId: string, reason?: string) =>
    api.post(`/teams/${teamId}/members/${memberId}/reject`, { reason }),
};

export const textCollectionApi = {
  list: (params?: any) => api.get('/text-collections', { params }),
  detail: (id: string) => api.get(`/text-collections/${id}`),
  create: (data: any) => api.post('/text-collections', data),
  batchCreate: (data: any) => api.post('/text-collections/batch', data),
  uploadTemplate: (taskId: string, formData: FormData) =>
    api.post(`/text-collections/upload-template/${taskId}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  assign: (data: any) => api.post('/text-collections/assign', data),
  recycle: () => api.post('/text-collections/recycle'),
  update: (id: string, data: any) => api.patch(`/text-collections/${id}`, data),
  remove: (id: string) => api.delete(`/text-collections/${id}`),
  getStats: (taskId: string) => api.get(`/text-collections/stats/${taskId}`),
};

export const smsApi = {
  getLogs: (params?: any) => api.get('/sms/logs', { params }),
};

export const exportApi = {
  tasks: (params?: any) => api.get('/admin/export/tasks', { params, responseType: params?.format === 'json' ? 'json' : 'blob' }),
  submissions: (params?: any) => api.get('/admin/export/submissions', { params, responseType: params?.format === 'json' ? 'json' : 'blob' }),
  audioLinks: (params?: any) => api.get('/admin/export/audio-links', { params }),
};

export const projectDocumentApi = {
  list: (projectId: string) => api.get(`/projects/${projectId}/documents`),
  detail: (projectId: string, docId: string) => api.get(`/projects/${projectId}/documents/${docId}`),
  create: (projectId: string, data: { title: string; content: string; fileName?: string }) =>
    api.post(`/projects/${projectId}/documents`, data),
  batchCreate: (projectId: string, data: { documents: { title: string; content: string; fileName?: string }[] }) =>
    api.post(`/projects/${projectId}/documents/batch`, data),
  upload: (projectId: string, file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post(`/projects/${projectId}/documents/upload`, formData);
  },
  remove: (projectId: string, docId: string) => api.delete(`/projects/${projectId}/documents/${docId}`),
};
