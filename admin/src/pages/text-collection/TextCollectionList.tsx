import { useState, useEffect } from 'react';
import {
  Table, Button, Space, Card, Tag, Input, Select, Modal,
  Form, message, InputNumber, Switch,
} from 'antd';
import {
  SwapOutlined, ReloadOutlined,
} from '@ant-design/icons';
import { textCollectionApi, taskApi } from '../../api';

const statusMap: Record<string, { label: string; color: string }> = {
  pending: { label: '待分配', color: 'default' },
  assigned: { label: '已分配', color: 'blue' },
  collecting: { label: '采集中', color: 'orange' },
  completed: { label: '已完成', color: 'green' },
  qc_failed: { label: '质检未通过', color: 'red' },
};

export default function TextCollectionList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [taskIdFilter, setTaskIdFilter] = useState<string | undefined>();
  const [statusFilter, setStatusFilter] = useState<string | undefined>();
  const [tasks, setTasks] = useState<any[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [assignModal, setAssignModal] = useState(false);
  const [assignForm] = Form.useForm();

  useEffect(() => { loadTasks(); }, []);
  useEffect(() => { loadTexts(); }, [page, taskIdFilter, statusFilter]);
  useEffect(() => { if (taskIdFilter) loadStats(); }, [taskIdFilter]);

  const loadTasks = async () => {
    try {
      const res: any = await taskApi.list({ type: 'text', pageSize: 100 });
      setTasks(res.items || []);
    } catch { /* ignore */ }
  };

  const loadTexts = async () => {
    setLoading(true);
    try {
      const res: any = await textCollectionApi.list({
        page, pageSize: 20,
        taskId: taskIdFilter,
        status: statusFilter,
      });
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch { message.error('加载文本列表失败'); }
    finally { setLoading(false); }
  };

  const loadStats = async () => {
    try {
      const res: any = await textCollectionApi.getStats(taskIdFilter!);
      setStats(res);
    } catch { /* ignore */ }
  };

  const handleAssign = async () => {
    try {
      const values = await assignForm.validateFields();
      await textCollectionApi.assign({ ...values, taskId: taskIdFilter });
      message.success('分配成功');
      setAssignModal(false);
      assignForm.resetFields();
      loadTexts();
      if (taskIdFilter) loadStats();
    } catch (e: any) {
      if (e.response) message.error(e.response?.data?.message || '分配失败');
    }
  };

  const handleRecycle = async () => {
    try {
      const res: any = await textCollectionApi.recycle();
      message.success(`已回收 ${res.recycled} 条文本`);
      loadTexts();
      if (taskIdFilter) loadStats();
    } catch { message.error('回收失败'); }
  };

  const columns = [
    { title: '序号', dataIndex: 'sortOrder', key: 'sortOrder', width: 60 },
    {
      title: '文本内容', dataIndex: 'content', key: 'content', ellipsis: true,
      render: (v: string) => <span style={{ maxWidth: 300, display: 'inline-block', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{v}</span>,
    },
    {
      title: '格式', dataIndex: 'format', key: 'format', width: 80,
      render: (v: string) => <Tag>{v === 'sml' ? 'SML' : '纯文本'}</Tag>,
    },
    {
      title: '状态', dataIndex: 'status', key: 'status', width: 100,
      render: (v: string) => { const s = statusMap[v] || { label: v, color: 'default' }; return <Tag color={s.color}>{s.label}</Tag>; },
    },
    { title: '分配用户', dataIndex: 'assignedUserName', key: 'assignedUserName', width: 120, render: (v: string) => v || '-' },
    { title: '创建时间', dataIndex: 'createdAt', key: 'createdAt', width: 170, render: (v: string) => v ? new Date(v).toLocaleString() : '-' },
  ];

  return (
    <Card title="文本采集管理">
      <Space style={{ marginBottom: 16 }} wrap>
        <Select allowClear placeholder="选择任务" style={{ width: 200 }} value={taskIdFilter}
          onChange={setTaskIdFilter} options={tasks.map((t: any) => ({ label: t.title, value: t.id }))} />
        <Select allowClear placeholder="状态" style={{ width: 120 }} value={statusFilter}
          onChange={setStatusFilter} options={Object.entries(statusMap).map(([v, { label }]) => ({ label, value: v }))} />
        <Button type="primary" icon={<SwapOutlined />} onClick={() => setAssignModal(true)} disabled={!taskIdFilter}>分配文本</Button>
        <Button icon={<ReloadOutlined />} onClick={handleRecycle}>回收过期</Button>
      </Space>

      {stats && (
        <div style={{ marginBottom: 16, padding: 12, background: '#fafafa', borderRadius: 8 }}>
          <Space size="large">
            <span>总计: <b>{stats.total}</b></span>
            <span>待分配: <b>{stats.pending}</b></span>
            <span>已分配: <b style={{ color: '#1890ff' }}>{stats.assigned}</b></span>
            <span>采集中: <b style={{ color: '#fa8c16' }}>{stats.collecting}</b></span>
            <span>已完成: <b style={{ color: '#52c41a' }}>{stats.completed}</b></span>
            <span>质检未通过: <b style={{ color: '#ff4d4f' }}>{stats.qcFailed}</b></span>
          </Space>
        </div>
      )}

      <Table rowKey="id" columns={columns} dataSource={data} loading={loading}
        pagination={{ current: page, total, pageSize: 20, onChange: setPage, showTotal: (t) => `共 ${t} 条` }} />

      <Modal title="分配文本" open={assignModal} onOk={handleAssign} onCancel={() => setAssignModal(false)}>
        <Form form={assignForm} layout="vertical">
          <Form.Item name="autoAssign" label="自动分配" valuePropName="checked">
            <Switch />
          </Form.Item>
          <Form.Item name="assignedUserId" label="指定用户ID">
            <Input placeholder="手动指定分配给某用户" />
          </Form.Item>
          <Form.Item name="assignCount" label="分配人数">
            <InputNumber min={0} style={{ width: '100%' }} placeholder="0=自动计算" />
          </Form.Item>
          <Form.Item name="copyForAssign" label="复制多份分配" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </Card>
  );
}
