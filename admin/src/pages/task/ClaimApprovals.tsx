import { useState, useEffect } from 'react';
import { Table, Button, Space, Card, message, Modal, Popconfirm } from 'antd';
import { CheckOutlined, CloseOutlined, DeleteOutlined } from '@ant-design/icons';
import { taskApi } from '../../api';

export default function ClaimApprovals() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);

  useEffect(() => { loadClaims(); }, [page]);

  const loadClaims = async () => {
    setLoading(true);
    try {
      const res: any = await taskApi.pendingClaims({ page, pageSize: 20 });
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch { message.error('加载申请列表失败'); }
    finally { setLoading(false); }
  };

  const handleApprove = async (claimId: string) => {
    try {
      await taskApi.approveClaim(claimId);
      message.success('已通过审批');
      loadClaims();
    } catch { message.error('审批失败'); }
  };

  const handleReject = async (claimId: string) => {
    Modal.confirm({
      title: '拒绝申请',
      content: '确认拒绝此任务申请？',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await taskApi.rejectClaim(claimId);
          message.success('已拒绝');
          loadClaims();
        } catch { message.error('操作失败'); }
      },
    });
  };

  const handleDelete = async (claimId: string) => {
    try {
      await taskApi.deleteClaim(claimId);
      message.success('已删除');
      loadClaims();
    } catch { message.error('删除失败'); }
  };

  const handleClearAll = () => {
    Modal.confirm({
      title: '清除所有任务数据',
      content: '此操作将删除所有任务和申请记录，不可恢复！',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          const res: any = await taskApi.clearAllData();
          message.success(`已清除 ${res.tasksDeleted} 个任务, ${res.claimsDeleted} 条申请`);
          loadClaims();
        } catch { message.error('清除失败'); }
      },
    });
  };

  const columns = [
    {
      title: '申请人', key: 'user', render: (_: any, r: any) => r.user?.nickname || r.user?.phone || r.userId?.substring(0, 8),
    },
    {
      title: '联系方式', key: 'contact', render: (_: any, r: any) => r.user?.phone || '-',
    },
    {
      title: '任务', key: 'task', render: (_: any, r: any) => r.task?.title || r.taskId?.substring(0, 8),
    },
    {
      title: '归属团队', key: 'team', render: (_: any, r: any) => r.task?.team?.name ?? '-',
    },
    {
      title: '申请时间', dataIndex: 'createdAt', key: 'createdAt', width: 170,
      render: (v: string) => v ? new Date(v).toLocaleString() : '-',
    },
    {
      title: '操作', key: 'action', width: 180,
      render: (_: any, record: any) => (
        <Space>
          <Button type="primary" size="small" icon={<CheckOutlined />} onClick={() => handleApprove(record.id)}>
            通过
          </Button>
          <Button danger size="small" icon={<CloseOutlined />} onClick={() => handleReject(record.id)}>
            拒绝
          </Button>
          <Popconfirm title="确认删除？" onConfirm={() => handleDelete(record.id)}>
            <Button size="small" icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <Card title="任务申请审批" extra={
      <Button danger onClick={handleClearAll}>清除所有任务数据</Button>
    }>
      {total > 0 && (
        <div style={{ marginBottom: 16, color: '#fa8c16' }}>
          当前有 <b>{total}</b> 条待审批申请
        </div>
      )}
      <Table
        rowKey="id"
        columns={columns}
        dataSource={data}
        loading={loading}
        pagination={{ current: page, total, pageSize: 20, onChange: setPage }}
      />
    </Card>
  );
}
