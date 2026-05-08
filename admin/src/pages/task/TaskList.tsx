import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, Button, Space, Card, Tag, Select, Input, Modal, message } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import { taskApi } from '../../api';

const { Search } = Input;

const typeColors: Record<string, string> = {
  audio: 'blue',
  image: 'green',
  video: 'orange',
  text: 'purple',
};

const statusMap: Record<string, { label: string; color: string }> = {
  draft: { label: '草稿', color: 'default' },
  published: { label: '已发布', color: 'blue' },
  in_progress: { label: '进行中', color: 'green' },
  completed: { label: '已完成', color: 'cyan' },
  closed: { label: '已关闭', color: 'red' },
};

export default function TaskList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [typeFilter, setTypeFilter] = useState<string | undefined>();
  const [statusFilter, setStatusFilter] = useState<string | undefined>();
  const navigate = useNavigate();

  useEffect(() => {
    loadTasks();
  }, [page, typeFilter, statusFilter]);

  const loadTasks = async () => {
    setLoading(true);
    try {
      const res: any = await taskApi.list({
        page,
        pageSize: 20,
        type: typeFilter,
        status: statusFilter,
      });
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch {
      message.error('加载任务失败');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (keyword: string) => {
    if (!keyword) {
      loadTasks();
      return;
    }
    try {
      const res: any = await taskApi.list({ keyword, page: 1, pageSize: 20 });
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch {
      message.error('搜索失败');
    }
  };

  const handleDelete = (id: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '删除后不可恢复，确认要删除此任务吗？',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await taskApi.remove(id);
          message.success('删除成功');
          loadTasks();
        } catch {
          message.error('删除失败');
        }
      },
    });
  };

  const handlePublish = async (id: string) => {
    try {
      await taskApi.update(id, { status: 'published' });
      message.success('已发布');
      loadTasks();
    } catch {
      message.error('发布失败');
    }
  };

  const columns = [
    { title: '任务标题', dataIndex: 'title', key: 'title', ellipsis: true },
    {
      title: '类型',
      dataIndex: 'type',
      key: 'type',
      render: (type: string) => <Tag color={typeColors[type]}>{type}</Tag>,
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => {
        const s = statusMap[status] || { label: status, color: 'default' };
        return <Tag color={s.color}>{s.label}</Tag>;
      },
    },
    { title: '单价', dataIndex: 'unitPrice', key: 'unitPrice', render: (v: number) => `¥${v}` },
    { title: '总量', dataIndex: 'totalQuantity', key: 'totalQuantity' },
    { title: '已领', dataIndex: 'claimedQuantity', key: 'claimedQuantity' },
    { title: '已完成', dataIndex: 'completedQuantity', key: 'completedQuantity' },
    {
      title: '操作',
      key: 'action',
      width: 240,
      render: (_: any, record: any) => (
        <Space>
          <Button type="link" onClick={() => navigate(`/tasks/${record.id}`)}>
            查看
          </Button>
          <Button type="link" onClick={() => navigate(`/tasks/${record.id}/edit`)}>
            编辑
          </Button>
          {record.status === 'draft' && (
            <Button type="link" style={{ color: '#52c41a' }} onClick={() => handlePublish(record.id)}>
              发布
            </Button>
          )}
          <Button type="link" danger onClick={() => handleDelete(record.id)}>
            删除
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <Card
      title="任务管理"
      extra={
        <Button type="primary" icon={<PlusOutlined />} onClick={() => navigate('/tasks/create')}>
          新建任务
        </Button>
      }
    >
      <Space style={{ marginBottom: 16 }}>
        <Select
          placeholder="任务类型"
          allowClear
          style={{ width: 120 }}
          value={typeFilter}
          onChange={setTypeFilter}
          options={[
            { label: '语音', value: 'audio' },
            { label: '图像', value: 'image' },
            { label: '视频', value: 'video' },
            { label: '文本', value: 'text' },
          ]}
        />
        <Select
          placeholder="状态"
          allowClear
          style={{ width: 120 }}
          value={statusFilter}
          onChange={setStatusFilter}
          options={Object.entries(statusMap).map(([value, { label }]) => ({ label, value }))}
        />
        <Search placeholder="搜索任务" onSearch={handleSearch} style={{ width: 200 }} />
      </Space>
      <Table
        rowKey="id"
        columns={columns}
        dataSource={data}
        loading={loading}
        pagination={{
          current: page,
          total,
          pageSize: 20,
          onChange: setPage,
        }}
      />
    </Card>
  );
}
