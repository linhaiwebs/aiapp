import React, { useEffect, useState } from 'react';
import { Table, Tag, Space, Button, Card, Modal, Select, message, Input } from 'antd';
import { CheckOutlined, CloseOutlined, ReloadOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';
import { taskApi, projectApi } from '../../api';

interface TaskRecord {
  id: string;
  title: string;
  type: string;
  typeLabel?: string;
  team?: { id: string; name: string };
  project?: { id: string; name: string };
  unitPrice: number;
  totalQuantity: number;
  status: string;
  reviewStatus: string;
  createdAt: string;
}

const typeLabels: Record<string, string> = {
  audio: '音频',
  image: '图像',
  video: '视频',
  text: '文本',
};

const typeColors: Record<string, string> = {
  audio: 'orange',
  image: 'blue',
  video: 'purple',
  text: 'green',
};

const TaskReview: React.FC = () => {
  const [data, setData] = useState<TaskRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [pagination, setPagination] = useState({ current: 1, pageSize: 20, total: 0 });
  const [modalOpen, setModalOpen] = useState(false);
  const [currentTask, setCurrentTask] = useState<TaskRecord | null>(null);
  const [action, setAction] = useState<'approve' | 'reject'>('approve');
  const [projectId, setProjectId] = useState<string | undefined>(undefined);
  const [rejectReason, setRejectReason] = useState('');
  const [projects, setProjects] = useState<any[]>([]);
  const [submitting, setSubmitting] = useState(false);

  const fetchData = async (page = 1, pageSize = 20) => {
    setLoading(true);
    try {
      const [res, projRes] = await Promise.all([
        taskApi.pendingReview({ page, pageSize }),
        projectApi.list({ pageSize: 500 }),
      ]);
      setData((res.data?.items ?? []).map((t: any) => ({ ...t, typeLabel: typeLabels[t.type] || t.type })));
      setProjects(projRes.data?.items ?? []);
      setPagination(prev => ({
        ...prev,
        current: page,
        pageSize,
        total: res.data?.total ?? 0,
      }));
    } catch {
      message.error('加载失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchData(); }, []);

  const handleTableChange = (pag: any) => fetchData(pag.current, pag.pageSize);

  const openApprove = (task: TaskRecord) => {
    setCurrentTask(task);
    setAction('approve');
    setProjectId(task.project?.id || undefined);
    setRejectReason('');
    setModalOpen(true);
  };

  const openReject = (task: TaskRecord) => {
    setCurrentTask(task);
    setAction('reject');
    setProjectId(undefined);
    setRejectReason('');
    setModalOpen(true);
  };

  const handleSubmit = async () => {
    if (!currentTask) return;
    setSubmitting(true);
    try {
      await taskApi.review(currentTask.id, {
        action,
        projectId: action === 'approve' ? projectId : undefined,
        reason: action === 'reject' ? rejectReason : undefined,
      });
      message.success(action === 'approve' ? '已通过审核' : '已驳回');
      setModalOpen(false);
      fetchData(pagination.current, pagination.pageSize);
    } catch {
      message.error('操作失败');
    } finally {
      setSubmitting(false);
    }
  };

  const columns: ColumnsType<TaskRecord> = [
    { title: 'ID', dataIndex: 'id', width: 100, render: (id: string) => id?.substring(0, 8) ?? '-' },
    { title: '标题', dataIndex: 'title', width: 220, ellipsis: true },
    {
      title: '类型', dataIndex: 'type', width: 80,
      render: (t: string, r) => <Tag color={typeColors[t] || 'default'}>{r.typeLabel || t}</Tag>,
    },
    { title: '团队', key: 'team', width: 120, render: (_, r) => r.team?.name ?? '-' },
    { title: '单价', dataIndex: 'unitPrice', width: 80, render: (v: number) => `¥${v}` },
    { title: '数量', dataIndex: 'totalQuantity', width: 60 },
    {
      title: '创建时间', dataIndex: 'createdAt', width: 170,
      render: (t: string) => t ? new Date(t).toLocaleString() : '-',
    },
    {
      title: '操作', key: 'actions', width: 140, fixed: 'right',
      render: (_, r) => (
        <Space>
          <Button type="primary" size="small" icon={<CheckOutlined />} onClick={() => openApprove(r)}>通过</Button>
          <Button danger size="small" icon={<CloseOutlined />} onClick={() => openReject(r)}>驳回</Button>
        </Space>
      ),
    },
  ];

  return (
    <>
      <Card title="任务审核（团长创建）" extra={
        <Button icon={<ReloadOutlined />} onClick={() => fetchData(pagination.current, pagination.pageSize)}>刷新</Button>
      }>
        <Table
          rowKey="id"
          columns={columns}
          dataSource={data}
          loading={loading}
          pagination={pagination}
          onChange={handleTableChange}
          scroll={{ x: 1000 }}
          size="small"
          locale={{ emptyText: '暂无待审核任务' }}
        />
      </Card>

      <Modal
        title={action === 'approve' ? '审核通过' : '驳回任务'}
        open={modalOpen}
        onOk={handleSubmit}
        onCancel={() => setModalOpen(false)}
        confirmLoading={submitting}
        okText={action === 'approve' ? '通过' : '驳回'}
        okButtonProps={{ danger: action === 'reject' }}
      >
        <p style={{ marginBottom: 16 }}>
          任务：<strong>{currentTask?.title}</strong>
        </p>
        {action === 'approve' ? (
          <div>
            <label style={{ display: 'block', marginBottom: 8 }}>分配项目（可选）</label>
            <Select
              style={{ width: '100%' }}
              placeholder="选择归属项目"
              allowClear
              value={projectId}
              onChange={v => setProjectId(v)}
              options={projects.map((p: any) => ({ value: p.id, label: p.name }))}
            />
          </div>
        ) : (
          <div>
            <label style={{ display: 'block', marginBottom: 8 }}>驳回原因（可选）</label>
            <Input.TextArea
              rows={2}
              value={rejectReason}
              onChange={e => setRejectReason(e.target.value)}
              placeholder="请输入驳回原因"
            />
          </div>
        )}
      </Modal>
    </>
  );
};

export default TaskReview;
