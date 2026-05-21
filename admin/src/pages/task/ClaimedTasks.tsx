import React, { useEffect, useState } from 'react';
import { Table, Tag, Space, Input, Select, Button, Card, message, Popconfirm } from 'antd';
import { SearchOutlined, ReloadOutlined, DeleteOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';
import { taskApi, teamApi } from '../../api';

interface ClaimRecord {
  id: string;
  userId: string;
  taskId: string;
  status: string;
  createdAt: string;
  claimedAt?: string;
  user?: { nickname?: string; phone?: string };
  task?: { title: string; team?: { id: string; name: string } };
}

const statusColors: Record<string, string> = {
  pending_approval: 'orange',
  claimed: 'blue',
  in_progress: 'processing',
  submitted: 'purple',
  completed: 'green',
  abandoned: 'default',
  expired: 'default',
  rejected: 'red',
};

const statusLabels: Record<string, string> = {
  pending_approval: '待审批',
  claimed: '已领取',
  in_progress: '采集中',
  submitted: '已提交',
  completed: '已完成',
  abandoned: '已放弃',
  expired: '已过期',
  rejected: '已驳回',
};

const ClaimedTasks: React.FC = () => {
  const [data, setData] = useState<ClaimRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [teams, setTeams] = useState<any[]>([]);
  const [pagination, setPagination] = useState({ current: 1, pageSize: 20, total: 0 });
  const [filters, setFilters] = useState({ status: '', teamId: '', userId: '' });

  const fetchData = async (page = 1, pageSize = 20) => {
    setLoading(true);
    try {
      const [claimsRes, teamsRes] = await Promise.all([
        taskApi.allClaims({ page, pageSize, ...filters }),
        teamApi.list({ pageSize: 500 }),
      ]);
      setData(claimsRes.data?.items ?? []);
      setTeams(teamsRes.data?.items ?? []);
      setPagination(prev => ({
        ...prev,
        current: page,
        pageSize,
        total: claimsRes.data?.total ?? 0,
      }));
    } catch (e) {
      message.error('加载失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleTableChange = (pag: any) => {
    fetchData(pag.current, pag.pageSize);
  };

  const handleSearch = () => {
    fetchData(1, pagination.pageSize);
  };

  const handleDelete = async (claimId: string) => {
    try {
      await taskApi.deleteClaim(claimId);
      message.success('已删除认领记录');
      fetchData(pagination.current, pagination.pageSize);
    } catch { message.error('删除失败'); }
  };

  const columns: ColumnsType<ClaimRecord> = [
    {
      title: '认领ID',
      dataIndex: 'id',
      width: 100,
      render: (id: string) => id?.substring(0, 8) ?? '-',
    },
    {
      title: '任务',
      key: 'task',
      width: 200,
      render: (_, r) => r.task?.title ?? '-',
    },
    {
      title: '认领人',
      key: 'user',
      width: 120,
      render: (_, r) => r.user?.nickname || r.user?.phone || '-',
    },
    {
      title: '手机号',
      key: 'phone',
      width: 130,
      render: (_, r) => r.user?.phone ?? '-',
    },
    {
      title: '归属团队',
      key: 'team',
      width: 130,
      render: (_, r) => r.task?.team?.name ?? '-',
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (s: string) => <Tag color={statusColors[s] || 'default'}>{statusLabels[s] ?? s}</Tag>,
    },
    {
      title: '认领时间',
      dataIndex: 'claimedAt',
      width: 170,
      render: (t: string) => t ? new Date(t).toLocaleString() : '-',
    },
    {
      title: '创建时间',
      dataIndex: 'createdAt',
      width: 170,
      render: (t: string) => new Date(t).toLocaleString(),
    },
    {
      title: '操作',
      key: 'action',
      width: 80,
      render: (_: any, r: ClaimRecord) => (
        <Popconfirm
          title="确认删除此认领记录？会同时清除该用户的文本分配"
          onConfirm={() => handleDelete(r.id)}
        >
          <Button type="link" danger icon={<DeleteOutlined />} size="small" />
        </Popconfirm>
      ),
    },
  ];

  return (
    <Card title="任务认领记录" extra={
      <Button icon={<ReloadOutlined />} onClick={() => fetchData(pagination.current, pagination.pageSize)}>
        刷新
      </Button>
    }>
      <Space style={{ marginBottom: 16 }} wrap>
        <Select
          placeholder="状态筛选"
          allowClear
          style={{ width: 120 }}
          value={filters.status || undefined}
          onChange={v => setFilters(f => ({ ...f, status: v || '' }))}
          options={Object.entries(statusLabels).map(([k, v]) => ({ value: k, label: v }))}
        />
        <Select
          placeholder="团队筛选"
          allowClear
          style={{ width: 160 }}
          value={filters.teamId || undefined}
          onChange={v => setFilters(f => ({ ...f, teamId: v || '' }))}
          options={teams.map((t: any) => ({ value: t.id, label: t.name }))}
        />
        <Input
          placeholder="用户ID"
          style={{ width: 160 }}
          value={filters.userId}
          onChange={e => setFilters(f => ({ ...f, userId: e.target.value }))}
          prefix={<SearchOutlined />}
          onPressEnter={handleSearch}
        />
        <Button type="primary" onClick={handleSearch} icon={<SearchOutlined />}>
          查询
        </Button>
      </Space>
      <Table
        rowKey="id"
        columns={columns}
        dataSource={data}
        loading={loading}
        pagination={pagination}
        onChange={handleTableChange}
        scroll={{ x: 1000 }}
        size="small"
      />
    </Card>
  );
};

export default ClaimedTasks;
