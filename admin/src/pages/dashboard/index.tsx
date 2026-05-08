import { useState, useEffect } from 'react';
import { Card, Col, Row, Statistic, Tag, Table, Spin, Progress } from 'antd';
import {
  ProjectOutlined,
  FileTextOutlined,
  UserOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  DollarOutlined,
  TeamOutlined,
} from '@ant-design/icons';
import { statsApi, submissionApi } from '../../api';

const statusColors: Record<string, string> = {
  pending_review: 'orange',
  approved: 'green',
  rejected: 'red',
  submitted: 'blue',
  draft: 'default',
};

const statusLabels: Record<string, string> = {
  pending_review: '待审核',
  approved: '已通过',
  rejected: '已驳回',
  submitted: '已提交',
  draft: '草稿',
};

export default function Dashboard() {
  const [stats, setStats] = useState<any>(null);
  const [recentSubmissions, setRecentSubmissions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const [statsRes, subsRes]: any[] = await Promise.all([
        statsApi.getStats(),
        submissionApi.all({ page: 1, pageSize: 5 }),
      ]);
      setStats(statsRes);
      setRecentSubmissions(subsRes.items || []);
    } catch {
      // Silently fail
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <Spin size="large" style={{ display: 'block', margin: '100px auto' }} />;
  if (!stats) return <div>加载失败</div>;

  const approveRate =
    stats.totalSubmissions > 0
      ? Math.round((stats.approvedSubmissions / stats.totalSubmissions) * 100)
      : 0;

  return (
    <div>
      <h2 style={{ marginBottom: 24 }}>数据概览</h2>

      {/* Core stats */}
      <Row gutter={[16, 16]}>
        <Col xs={12} sm={6}>
          <Card hoverable>
            <Statistic
              title="用户总数"
              value={stats.totalUsers}
              prefix={<UserOutlined />}
              valueStyle={{ color: '#1890ff' }}
            />
          </Card>
        </Col>
        <Col xs={12} sm={6}>
          <Card hoverable>
            <Statistic
              title="活跃任务"
              value={stats.activeTasks}
              prefix={<FileTextOutlined />}
              valueStyle={{ color: '#52c41a' }}
            />
          </Card>
        </Col>
        <Col xs={12} sm={6}>
          <Card hoverable>
            <Statistic
              title="待审核"
              value={stats.pendingReview}
              prefix={<ClockCircleOutlined />}
              valueStyle={{ color: stats.pendingReview > 0 ? '#fa8c16' : undefined }}
            />
            {stats.pendingReview > 0 && (
              <Tag color="orange" style={{ marginTop: 8 }}>需要处理</Tag>
            )}
          </Card>
        </Col>
        <Col xs={12} sm={6}>
          <Card hoverable>
            <Statistic
              title="总发放"
              value={stats.totalEarnings}
              prefix={<DollarOutlined />}
              precision={2}
              valueStyle={{ color: '#722ed1' }}
            />
          </Card>
        </Col>
      </Row>

      {/* Secondary stats */}
      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={12} sm={6}>
          <Card size="small">
            <Statistic title="项目数" value={stats.totalProjects} prefix={<ProjectOutlined />} />
          </Card>
        </Col>
        <Col xs={12} sm={6}>
          <Card size="small">
            <Statistic title="任务总数" value={stats.totalTasks} prefix={<FileTextOutlined />} />
          </Card>
        </Col>
        <Col xs={12} sm={6}>
          <Card size="small">
            <Statistic title="领取总量" value={stats.totalClaims} prefix={<TeamOutlined />} />
          </Card>
        </Col>
        <Col xs={12} sm={6}>
          <Card size="small">
            <Statistic title="采集总量" value={stats.totalSubmissions} prefix={<CheckCircleOutlined />} />
          </Card>
        </Col>
      </Row>

      {/* Distribution charts */}
      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} md={8}>
          <Card title="审核通过率" size="small">
            <div style={{ textAlign: 'center' }}>
              <Progress
                type="circle"
                percent={approveRate}
                format={() => `${approveRate}%`}
                strokeColor={approveRate >= 80 ? '#52c41a' : approveRate >= 60 ? '#fa8c16' : '#ff4d4f'}
                size={120}
              />
              <div style={{ marginTop: 8, color: '#666' }}>
                通过 {stats.approvedSubmissions} / 驳回 {stats.rejectedSubmissions}
              </div>
            </div>
          </Card>
        </Col>
        <Col xs={24} md={8}>
          <Card title="任务类型分布" size="small">
            {Object.entries(stats.taskTypeDistribution || {}).map(([type, count]) => (
              <div key={type} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                <Tag color={type === 'audio' ? 'blue' : type === 'image' ? 'green' : 'orange'}>
                  {type === 'audio' ? '语音' : type === 'image' ? '图像' : '视频'}
                </Tag>
                <span>{count as number}</span>
              </div>
            ))}
            {Object.keys(stats.taskTypeDistribution || {}).length === 0 && (
              <div style={{ color: '#999', textAlign: 'center' }}>暂无数据</div>
            )}
          </Card>
        </Col>
        <Col xs={24} md={8}>
          <Card title="用户角色分布" size="small">
            {Object.entries(stats.userRoleDistribution || {}).map(([role, count]) => (
              <div key={role} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                <Tag>{role === 'member' ? '会员' : role === 'leader' ? '团长' : role === 'super_admin' ? '超级管理员' : role}</Tag>
                <span>{count as number}</span>
              </div>
            ))}
            {Object.keys(stats.userRoleDistribution || {}).length === 0 && (
              <div style={{ color: '#999', textAlign: 'center' }}>暂无数据</div>
            )}
          </Card>
        </Col>
      </Row>

      {/* Recent submissions */}
      <Card title="最近提交" style={{ marginTop: 16 }} size="small">
        <Table
          rowKey="id"
          size="small"
          pagination={false}
          dataSource={recentSubmissions}
          columns={[
            {
              title: 'ID',
              dataIndex: 'id',
              width: 100,
              render: (v: string) => v.substring(0, 8),
            },
            {
              title: '任务',
              dataIndex: ['task', 'title'],
              ellipsis: true,
            },
            {
              title: '采集员',
              render: (_: any, r: any) => r.user?.nickname || r.user?.phone?.slice(-4) || '-',
              width: 100,
            },
            {
              title: '状态',
              dataIndex: 'status',
              width: 100,
              render: (s: string) => (
                <Tag color={statusColors[s] || 'default'}>{statusLabels[s] || s}</Tag>
              ),
            },
            {
              title: '提交时间',
              dataIndex: 'submittedAt',
              width: 170,
              render: (v: string) => (v ? new Date(v).toLocaleString() : '-'),
            },
          ]}
        />
      </Card>
    </div>
  );
}
