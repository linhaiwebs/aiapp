import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './stores/auth';
import MainLayout from './layouts/MainLayout';
import Login from './pages/login';
import Dashboard from './pages/dashboard';
import TaskList from './pages/task/TaskList';
import TaskDetail from './pages/task/TaskDetail';
import TaskForm from './pages/task/TaskCreate';
import UserList from './pages/user/UserList';
import SubmissionList from './pages/submission/SubmissionList';
import CategoryList from './pages/category/CategoryList';
import TeamList from './pages/team/TeamList';
import ClaimApprovals from './pages/task/ClaimApprovals';
import ClaimedTasks from './pages/task/ClaimedTasks';
import TaskReview from './pages/task/TaskReview';
import CollectionDataList from './pages/collection/CollectionDataList';
import DataExport from './pages/export/DataExport';
import ProjectList from './pages/project/ProjectList';
import ProjectDetail from './pages/project/ProjectDetail';
import ProjectForm from './pages/project/ProjectForm';

import SmsLogs from './pages/sms/SmsLogs';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore();
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore();
  if (isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }
  return <>{children}</>;
}

function App() {
  return (
    <Routes>
      <Route
        path="/login"
        element={
          <PublicRoute>
            <Login />
          </PublicRoute>
        }
      />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <MainLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<Dashboard />} />
        <Route path="tasks" element={<TaskList />} />
        <Route path="tasks/create" element={<TaskForm />} />
        <Route path="tasks/:id" element={<TaskDetail />} />
        <Route path="tasks/:id/edit" element={<TaskForm />} />
        <Route path="review/claims" element={<ClaimApprovals />} />
        <Route path="review/submissions" element={<SubmissionList />} />
        <Route path="claims" element={<ClaimedTasks />} />
        <Route path="review/tasks" element={<TaskReview />} />
        <Route path="collections/:type" element={<CollectionDataList />} />

        <Route path="projects" element={<ProjectList />} />
        <Route path="projects/new" element={<ProjectForm />} />
        <Route path="projects/:id" element={<ProjectDetail />} />
        <Route path="projects/:id/edit" element={<ProjectForm />} />
        <Route path="teams" element={<TeamList />} />
        <Route path="users" element={<UserList />} />
        <Route path="sms" element={<SmsLogs />} />
        <Route path="categories" element={<CategoryList />} />
        <Route path="export" element={<DataExport />} />
      </Route>
    </Routes>
  );
}

export default App;
