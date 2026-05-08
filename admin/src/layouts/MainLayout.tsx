import { useState, useEffect } from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import { Layout, Menu, Button, theme, Avatar, Dropdown } from 'antd';
import {
  DashboardOutlined,
  FileTextOutlined,
  LogoutOutlined,
  UserOutlined,
  AuditOutlined,
  TagsOutlined,
  DownOutlined,
  TeamOutlined,
  FolderOutlined,
  ExportOutlined,
  ProjectOutlined,
  MessageOutlined,
} from '@ant-design/icons';
import { useAuthStore } from '../stores/auth';
import { authApi } from '../api';

const { Header, Sider, Content } = Layout;

const menuItems = [
  { key: '/dashboard', icon: <DashboardOutlined />, label: '仪表盘' },
  { key: '/projects', icon: <ProjectOutlined />, label: '项目管理' },
  { key: '/tasks', icon: <FileTextOutlined />, label: '任务管理' },
  {
    key: '/review',
    icon: <AuditOutlined />,
    label: '审核项目',
    children: [
      { key: '/review/claims', label: '申请审批' },
      { key: '/review/submissions', label: '提交审核' },
    ],
  },
  {
    key: '/collections',
    icon: <FolderOutlined />,
    label: '采集管理',
    children: [
      { key: '/collections/text', label: '文本采集' },
      { key: '/collections/audio', label: '语音采集' },
      { key: '/collections/video', label: '视频采集' },
      { key: '/collections/image', label: '图像采集' },
    ],
  },
  { key: '/teams', icon: <TeamOutlined />, label: '团队管理' },
  { key: '/users', icon: <UserOutlined />, label: '用户管理' },
  { key: '/sms', icon: <MessageOutlined />, label: '验证码记录' },
  { key: '/categories', icon: <TagsOutlined />, label: '分类管理' },
  { key: '/export', icon: <ExportOutlined />, label: '数据导出' },
];

export default function MainLayout() {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();
  const { logout, user, setUser } = useAuthStore();
  const { token: { colorBgContainer } } = theme.useToken();

  useEffect(() => {
    if (!user) {
      authApi.getMe().then((res: any) => {
        if (res) setUser(res);
      }).catch(() => {});
    }
  }, []);

  const handleMenuClick = ({ key }: { key: string }) => {
    navigate(key);
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const selectedKey = location.pathname;
  const openKeys = location.pathname.startsWith('/collections') || location.pathname === '/text-collections' ? ['/collections'] :
                   location.pathname.startsWith('/review') ? ['/review'] : [];

  const userMenuItems = [
    {
      key: 'profile',
      label: user?.nickname || user?.phone || '管理员',
      disabled: true,
    },
    { type: 'divider' as const },
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: '退出登录',
      onClick: handleLogout,
    },
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider collapsible collapsed={collapsed} onCollapse={setCollapsed} width={200}>
        <div style={{
          height: 48,
          margin: '12px 16px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#fff',
          fontWeight: 'bold',
          fontSize: collapsed ? 16 : 18,
          letterSpacing: 1,
        }}>
          {collapsed ? '端' : '端云智采'}
        </div>
        <Menu
          theme="dark"
          selectedKeys={[selectedKey]}
          defaultOpenKeys={openKeys}
          mode="inline"
          items={menuItems}
          onClick={handleMenuClick}
        />
      </Sider>
      <Layout>
        <Header style={{
          padding: '0 24px',
          background: colorBgContainer,
          display: 'flex',
          justifyContent: 'flex-end',
          alignItems: 'center',
          borderBottom: '1px solid #f0f0f0',
        }}>
          <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
            <Button type="text" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Avatar size="small" icon={<UserOutlined />} />
              <span>{user?.nickname || user?.phone || '管理员'}</span>
              <DownOutlined style={{ fontSize: 10 }} />
            </Button>
          </Dropdown>
        </Header>
        <Content style={{ margin: '16px' }}>
          <div style={{
            padding: 24,
            minHeight: 360,
            background: colorBgContainer,
            borderRadius: 8,
          }}>
            <Outlet />
          </div>
        </Content>
      </Layout>
    </Layout>
  );
}
