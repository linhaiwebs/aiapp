import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, Button, Space, Card, Tag, Modal, message } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import { projectApi } from '../../api';

export default function ProjectList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const navigate = useNavigate();

  useEffect(() => {
    loadProjects();
  }, [page]);

  const loadProjects = async () => {
    setLoading(true);
    try {
      const res: any = await projectApi.list({ page, pageSize: 20 });
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch {
      message.error('加载项目失败');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '删除后不可恢复，确认要删除此项目吗？',
      onOk: async () => {
        try {
          await projectApi.remove(id);
          message.success('删除成功');
          loadProjects();
        } catch {
          message.error('删除失败');
        }
      },
    });
  };

  const columns = [
    { title: '项目名称', dataIndex: 'name', key: 'name', render: (v: string) => <strong>{v}</strong> },
    { title: '地区', dataIndex: 'region', key: 'region', width: 80, render: (v: string) => v || '-' },

    {
      title: '状态',
      dataIndex: 'isActive',
      key: 'isActive',
      width: 70,
      render: (v: boolean) => v ? <Tag color="green">启用</Tag> : <Tag color="red">禁用</Tag>,
    },
    {
      title: '授权签名',
      dataIndex: 'requireSignature',
      key: 'requireSignature',
      width: 80,
      render: (v: boolean) => v ? <Tag color="orange">需要</Tag> : '-',
    },
    {
      title: '任务数',
      key: 'taskCount',
      width: 70,
      render: (_: any, r: any) => r.tasks?.length ?? 0,
    },
    {
      title: '创建时间',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 170,
      render: (v: string) => v ? new Date(v).toLocaleString() : '-',
    },
    {
      title: '操作',
      key: 'action',
      width: 180,
      render: (_: any, record: any) => (
        <Space>
          <Button type="link" onClick={() => navigate(`/projects/${record.id}`)}>
            查看
          </Button>
          <Button type="link" onClick={() => navigate(`/projects/${record.id}/edit`)}>
            编辑
          </Button>
          <Button type="link" danger onClick={() => handleDelete(record.id)}>
            删除
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <Card
      title="项目管理"
      extra={
        <Button type="primary" icon={<PlusOutlined />} onClick={() => navigate('/projects/new')}>
          新建项目
        </Button>
      }
    >
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
          showTotal: (t) => `共 ${t} 条`,
        }}
      />
    </Card>
  );
}
