import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Descriptions, Spin, Tag, Button, message, Table, Space, Popconfirm, Select, Modal } from 'antd';
import { EditOutlined, ArrowLeftOutlined, EyeOutlined, DeleteOutlined } from '@ant-design/icons';
import { projectApi, taskApi } from '../../api';

const taskTypeLabels: Record<string, string> = {
  audio: '语音', image: '图像', video: '视频', text: '文本',
};

export default function ProjectDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [project, setProject] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [taskData, setTaskData] = useState<any[]>([]);
  const [taskLoading, setTaskLoading] = useState(false);
  const [taskTotal, setTaskTotal] = useState(0);
  const [taskPage, setTaskPage] = useState(1);
  const [selectedTaskKeys, setSelectedTaskKeys] = useState<React.Key[]>([]);
  const [batchStatusModal, setBatchStatusModal] = useState(false);
  const [batchStatus, setBatchStatus] = useState<string>('published');

  useEffect(() => {
    loadProject();
  }, [id]);

  useEffect(() => {
    if (id) loadTasks();
  }, [id, taskPage]);

  const loadProject = async () => {
    try {
      const res: any = await projectApi.detail(id!);
      setProject(res);
    } catch {
      message.error('加载项目失败');
    } finally {
      setLoading(false);
    }
  };

  const loadTasks = async () => {
    setTaskLoading(true);
    try {
      const res: any = await projectApi.getTasks(id!, { page: taskPage, pageSize: 10 });
      setTaskData(res.items || []);
      setTaskTotal(res.total || 0);
    } catch { message.error('加载任务列表失败'); }
    finally { setTaskLoading(false); }
  };

  const handleDeleteTask = async (taskId: string) => {
    try {
      await taskApi.remove(taskId);
      message.success('删除成功');
      loadTasks();
      loadProject();
    } catch { message.error('删除失败'); }
  };

  const handleBatchDeleteTasks = async () => {
    try {
      await projectApi.batchTasks(id!, { action: 'delete', ids: selectedTaskKeys });
      message.success('批量删除成功');
      setSelectedTaskKeys([]);
      loadTasks();
      loadProject();
    } catch { message.error('批量删除失败'); }
  };

  const handleBatchStatus = async () => {
    try {
      await projectApi.batchTasks(id!, { action: 'updateStatus', ids: selectedTaskKeys, status: batchStatus });
      message.success('批量修改成功');
      setBatchStatusModal(false);
      setSelectedTaskKeys([]);
      loadTasks();
    } catch { message.error('操作失败'); }
  };

  if (loading) return <Spin style={{ display: 'block', margin: '100px auto' }} />;
  if (!project) return <div>项目不存在</div>;

  const taskColumns = [
    {
      title: '标题', dataIndex: 'title', key: 'title', ellipsis: true,
      render: (v: string, r: any) => <a onClick={() => navigate(`/tasks/${r.id}`)} style={{ cursor: 'pointer' }}>{v}</a>,
    },
    {
      title: '类型', dataIndex: 'type', key: 'type', width: 80,
      render: (v: string) => <Tag>{taskTypeLabels[v] || v}</Tag>,
    },
    {
      title: '状态', dataIndex: 'status', key: 'status', width: 90,
      render: (v: string) => {
        const m: Record<string, string> = { draft: '草稿', published: '已发布', in_progress: '进行中', completed: '已完成', closed: '已关闭', archived: '已归档' };
        const c: Record<string, string> = { draft: 'default', published: 'blue', in_progress: 'processing', completed: 'green', closed: 'red', archived: 'default' };
        return <Tag color={c[v]}>{m[v] || v}</Tag>;
      },
    },
    {
      title: '单价', dataIndex: 'unitPrice', key: 'unitPrice', width: 70, render: (v: number) => `¥${v}`,
    },
    {
      title: '进度', key: 'progress', width: 100,
      render: (_: any, r: any) => `${r.completedQuantity || 0}/${r.totalQuantity || 0}`,
    },
    {
      title: '操作', key: 'action', width: 210,
      render: (_: any, r: any) => (
        <Space size="small">
          <Button type="link" size="small" icon={<EyeOutlined />} onClick={() => navigate(`/tasks/${r.id}`)}>查看</Button>
          <Button type="link" size="small" icon={<EditOutlined />} onClick={() => navigate(`/tasks/${r.id}/edit`)}>编辑</Button>
          <Popconfirm title="确认删除？" onConfirm={() => handleDeleteTask(r.id)}>
            <Button type="link" size="small" danger icon={<DeleteOutlined />}>删除</Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <Button
        type="text"
        icon={<ArrowLeftOutlined />}
        onClick={() => navigate('/projects')}
        style={{ marginBottom: 16 }}
      >
        返回列表
      </Button>
      <Card
        title={project.name}
        extra={
          <Button
            type="primary"
            icon={<EditOutlined />}
            onClick={() => navigate(`/projects/${id}/edit`)}
          >
            编辑
          </Button>
        }
      >
        <Descriptions bordered column={2} size="small">
          <Descriptions.Item label="项目名称">{project.name}</Descriptions.Item>
          <Descriptions.Item label="状态">
            {project.isActive ? <Tag color="green">启用</Tag> : <Tag color="red">禁用</Tag>}
          </Descriptions.Item>
          <Descriptions.Item label="描述" span={2}>
            {project.description || '-'}
          </Descriptions.Item>
          <Descriptions.Item label="开始日期">
            {project.startDate ? new Date(project.startDate).toLocaleDateString() : '-'}
          </Descriptions.Item>
          <Descriptions.Item label="结束日期">
            {project.endDate ? new Date(project.endDate).toLocaleDateString() : '-'}
          </Descriptions.Item>
          <Descriptions.Item label="项目地区">{project.region || '-'}</Descriptions.Item>
          <Descriptions.Item label="部门识别方式">{project.department || '-'}</Descriptions.Item>
          <Descriptions.Item label="负责人">{project.owner?.nickname || project.owner?.phone || project.ownerId || '-'}</Descriptions.Item>
          <Descriptions.Item label="验收人">{project.acceptor?.nickname || project.acceptor?.phone || project.acceptorId || '-'}</Descriptions.Item>
          <Descriptions.Item label="授权签名">
            {project.requireSignature ? <Tag color="orange">需要</Tag> : <Tag>不需要</Tag>}
          </Descriptions.Item>
          <Descriptions.Item label="回收时间">{project.recycleHours ? `${project.recycleHours}小时` : '-'}</Descriptions.Item>
          <Descriptions.Item label="任务总数">
            {project.tasks?.length ?? 0}
          </Descriptions.Item>
          <Descriptions.Item label="创建时间">
            {project.createdAt ? new Date(project.createdAt).toLocaleString() : '-'}
          </Descriptions.Item>
          <Descriptions.Item label="更新时间">
            {project.updatedAt ? new Date(project.updatedAt).toLocaleString() : '-'}
          </Descriptions.Item>
        </Descriptions>

        <div style={{ marginTop: 24 }}>
          <h4>项目下的任务</h4>
          <Space style={{ marginBottom: 12 }}>
            {selectedTaskKeys.length > 0 && (
              <>
                <Popconfirm title={`确认删除选中的 ${selectedTaskKeys.length} 个任务？`} onConfirm={handleBatchDeleteTasks}>
                  <Button danger icon={<DeleteOutlined />}>
                    批量删除({selectedTaskKeys.length})
                  </Button>
                </Popconfirm>
                <Button onClick={() => setBatchStatusModal(true)}>
                  批量修改状态
                </Button>
              </>
            )}
          </Space>
          <Table
            rowKey="id"
            dataSource={taskData}
            loading={taskLoading}
            columns={taskColumns}
            rowSelection={{ selectedRowKeys: selectedTaskKeys, onChange: setSelectedTaskKeys }}
            pagination={{
              current: taskPage,
              total: taskTotal,
              pageSize: 10,
              onChange: setTaskPage,
              showTotal: (t) => `共 ${t} 条`,
            }}
          />
        </div>

        <Modal title="批量修改任务状态" open={batchStatusModal}
          onOk={handleBatchStatus} onCancel={() => setBatchStatusModal(false)}>
          <Select style={{ width: '100%' }} value={batchStatus} onChange={setBatchStatus}
            options={[
              { label: '已发布', value: 'published' },
              { label: '进行中', value: 'in_progress' },
              { label: '已完成', value: 'completed' },
              { label: '已关闭', value: 'closed' },
              { label: '已归档', value: 'archived' },
            ]} />
        </Modal>
      </Card>
    </div>
  );
}
