import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, Button, Space, Card, Tag, Select, Input, Modal, message, Popconfirm } from 'antd';
import { PlusOutlined, DeleteOutlined, EditOutlined } from '@ant-design/icons';
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
  archived: { label: '已归档', color: 'default' },
};

export default function TaskList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [typeFilter, setTypeFilter] = useState<string | undefined>();
  const [statusFilter, setStatusFilter] = useState<string | undefined>();
  const navigate = useNavigate();
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);
  const [batchDeleting, setBatchDeleting] = useState(false);
  const [batchStatusModal, setBatchStatusModal] = useState(false);
  const [batchStatus, setBatchStatus] = useState<string>('published');

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

  const handleBatchDelete = async () => {
    setBatchDeleting(true);
    try {
      await taskApi.batchDelete(selectedRowKeys as string[]);
      message.success(`成功删除 ${selectedRowKeys.length} 条任务`);
      setSelectedRowKeys([]);
      loadTasks();
    } catch (e: any) {
      message.error(e.response?.data?.message || '批量删除失败');
    } finally {
      setBatchDeleting(false);
    }
  };

  const handleBatchStatus = async () => {
    try {
      await taskApi.batchUpdateStatus(selectedRowKeys as string[], batchStatus);
      message.success(`成功更新 ${selectedRowKeys.length} 条任务状态`);
      setBatchStatusModal(false);
      setSelectedRowKeys([]);
      loadTasks();
    } catch (e: any) {
      message.error(e.response?.data?.message || '操作失败');
    }
  };

  const columns = [
    {
      title: '任务标题', dataIndex: 'title', key: 'title', ellipsis: true, width: 200,
      render: (v: string) => <span title={v}>{v}</span>,
    },
    {
      title: '类型', dataIndex: 'type', key: 'type', width: 70,
      render: (type: string) => <Tag color={typeColors[type]}>{type}</Tag>,
    },
    {
      title: '状态', dataIndex: 'status', key: 'status', width: 80,
      render: (status: string) => {
        const s = statusMap[status] || { label: status, color: 'default' };
        return <Tag color={s.color}>{s.label}</Tag>;
      },
    },
    { title: '单价', dataIndex: 'unitPrice', key: 'unitPrice', width: 70, render: (v: number) => `¥${v}` },
    { title: '总量', dataIndex: 'totalQuantity', key: 'totalQuantity', width: 60 },
    { title: '已领', dataIndex: 'claimedQuantity', key: 'claimedQuantity', width: 60 },
    { title: '已完成', dataIndex: 'completedQuantity', key: 'completedQuantity', width: 70 },
    {
      title: '操作', key: 'action', width: 180,
      render: (_: any, record: any) => (
        <Space size={0}>
          <Button type="link" size="small" onClick={() => navigate(`/tasks/${record.id}`)}>查看</Button>
          <Button type="link" size="small" onClick={() => navigate(`/tasks/${record.id}/edit`)}>编辑</Button>
          {record.status === 'draft' && (
            <Button type="link" size="small" style={{ color: '#52c41a' }} onClick={() => handlePublish(record.id)}>发布</Button>
          )}
          <Button type="link" size="small" danger onClick={() => handleDelete(record.id)}>删除</Button>
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
          onChange={(v) => { setTypeFilter(v); setSelectedRowKeys([]); }}
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
          onChange={(v) => { setStatusFilter(v); setSelectedRowKeys([]); }}
          options={Object.entries(statusMap).map(([value, { label }]) => ({ label, value }))}
        />
        <Search placeholder="搜索任务" onSearch={handleSearch} style={{ width: 200 }} />
      </Space>

      <Space style={{ marginBottom: 16 }}>
        {selectedRowKeys.length > 0 && (
          <>
            <Popconfirm
              title={`确认删除选中的 ${selectedRowKeys.length} 个任务？`}
              onConfirm={handleBatchDelete}
            >
              <Button danger icon={<DeleteOutlined />} loading={batchDeleting}>
                批量删除({selectedRowKeys.length})
              </Button>
            </Popconfirm>
            <Button icon={<EditOutlined />} onClick={() => setBatchStatusModal(true)}>
              批量修改状态
            </Button>
          </>
        )}
      </Space>

      <Table
        rowKey="id"
        columns={columns}
        dataSource={data}
        loading={loading}
        rowSelection={{
          selectedRowKeys,
          onChange: setSelectedRowKeys,
        }}
        pagination={{
          current: page,
          total,
          pageSize: 20,
          onChange: setPage,
        }}
      />

      <Modal
        title="批量修改任务状态"
        open={batchStatusModal}
        onOk={handleBatchStatus}
        onCancel={() => setBatchStatusModal(false)}
      >
        <Select
          style={{ width: '100%' }}
          value={batchStatus}
          onChange={setBatchStatus}
          placeholder="选择目标状态"
          options={[
            { label: '已发布', value: 'published' },
            { label: '进行中', value: 'in_progress' },
            { label: '已完成', value: 'completed' },
            { label: '已关闭', value: 'closed' },
            { label: '已归档', value: 'archived' },
          ]}
        />
      </Modal>
    </Card>
  );
}
