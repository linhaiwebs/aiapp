import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, Button, Space, Card, Tag, Modal, message, List, Popconfirm, Tabs, Input, Form } from 'antd';
import { PlusOutlined, FileTextOutlined, UploadOutlined, DeleteOutlined, EditOutlined } from '@ant-design/icons';
import { projectApi, projectDocumentApi } from '../../api';

export default function ProjectList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const navigate = useNavigate();

  // 文档上传弹窗
  const [docModalVisible, setDocModalVisible] = useState(false);
  const [docProjectId, setDocProjectId] = useState('');
  const [docProjectName, setDocProjectName] = useState('');
  const [documents, setDocuments] = useState<any[]>([]);
  const [docsLoading, setDocsLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [savingManual, setSavingManual] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [manualForm] = Form.useForm();

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

  const loadDocuments = async (projectId: string) => {
    setDocsLoading(true);
    try {
      const res: any = await projectDocumentApi.list(projectId);
      setDocuments(Array.isArray(res) ? res : []);
    } catch {
      message.error('加载文档列表失败');
    } finally {
      setDocsLoading(false);
    }
  };

  const openDocModal = (record: any) => {
    setDocProjectId(record.id);
    setDocProjectName(record.name);
    setDocModalVisible(true);
    loadDocuments(record.id);
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setUploading(true);
    try {
      const documents: { title: string; content: string; fileName: string }[] = [];
      for (const file of Array.from(files)) {
        const content = await file.text();
        documents.push({
          title: file.name.replace(/\.[^.]+$/i, ''),
          content,
          fileName: file.name,
        });
      }
      await projectDocumentApi.batchCreate(docProjectId, { documents });
      message.success(`成功上传 ${documents.length} 个文档`);
      loadDocuments(docProjectId);
    } catch {
      message.error('上传失败');
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleDeleteDoc = async (docId: string) => {
    try {
      await projectDocumentApi.remove(docProjectId, docId);
      message.success('删除成功');
      loadDocuments(docProjectId);
    } catch {
      message.error('删除失败');
    }
  };

  const handleSaveManual = async () => {
    try {
      const values = await manualForm.validateFields();
      setSavingManual(true);
      await projectDocumentApi.create(docProjectId, {
        title: values.title,
        content: values.content,
        fileName: values.title,
      });
      message.success('文案保存成功');
      manualForm.resetFields();
      loadDocuments(docProjectId);
    } catch (e: any) {
      if (e.errorFields) return; // form validation
      message.error('保存失败');
    } finally {
      setSavingManual(false);
    }
  };

  const columns = [
    { title: '项目名称', dataIndex: 'name', key: 'name', render: (v: string) => <strong>{v}</strong> },
    { title: '地区', dataIndex: 'region', key: 'region', width: 80, render: (v: string) => v || '-' },
    {
      title: '所属团队',
      key: 'team',
      width: 120,
      render: (_: any, r: any) => r.team?.name || <span style={{ color: '#999' }}>未指定</span>,
    },
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
      width: 260,
      render: (_: any, record: any) => (
        <Space>
          <Button type="link" onClick={() => navigate(`/projects/${record.id}`)}>
            查看
          </Button>
          <Button type="link" onClick={() => navigate(`/projects/${record.id}/edit`)}>
            编辑
          </Button>
          <Button type="link" icon={<FileTextOutlined />} onClick={() => openDocModal(record)}>
            上传文本
          </Button>
          <Button type="link" danger onClick={() => handleDelete(record.id)}>
            删除
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <>
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

      <Modal
        title={`文本管理 - ${docProjectName}`}
        open={docModalVisible}
        onCancel={() => setDocModalVisible(false)}
        footer={null}
        width={640}
      >
        <Tabs
          items={[
            {
              key: 'upload',
              label: '上传文档',
              children: (
                <>
                  <div style={{ marginBottom: 16 }}>
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept=".txt,.text,.csv,.json,.md,.xml,.yaml,.yml,.log,.srt,.vtt,.html,.htm,.sml"
                      multiple
                      style={{ display: 'none' }}
                      onChange={handleFileSelect}
                    />
                    <Button
                      type="primary"
                      icon={<UploadOutlined />}
                      loading={uploading}
                      onClick={() => fileInputRef.current?.click()}
                    >
                      选择文件上传（支持多选，UTF-8编码）
                    </Button>
                  </div>

                  <List
                    loading={docsLoading}
                    dataSource={documents}
                    locale={{ emptyText: '暂无上传的文档' }}
                    renderItem={(item: any) => (
                      <List.Item
                        actions={[
                          <Popconfirm
                            key="del"
                            title="确认删除此文档？"
                            onConfirm={() => handleDeleteDoc(item.id)}
                          >
                            <Button type="link" danger icon={<DeleteOutlined />} size="small" />
                          </Popconfirm>,
                        ]}
                      >
                        <List.Item.Meta
                          title={item.title}
                          description={`${item.fileName || '-'}  ·  ${new Date(item.createdAt).toLocaleString()}`}
                        />
                      </List.Item>
                    )}
                  />
                </>
              ),
            },
            {
              key: 'edit',
              label: '编辑文案',
              children: (
                <Form form={manualForm} layout="vertical">
                  <Form.Item
                    name="title"
                    label="文案标题"
                    rules={[{ required: true, message: '请输入文案标题' }]}
                  >
                    <Input placeholder="如：任务要求说明" />
                  </Form.Item>
                  <Form.Item
                    name="content"
                    label="文案内容"
                    rules={[{ required: true, message: '请输入文案内容' }]}
                  >
                    <Input.TextArea rows={10} placeholder="输入文本内容，将作为任务说明的参考模板" />
                  </Form.Item>
                  <Form.Item>
                    <Button
                      type="primary"
                      icon={<EditOutlined />}
                      loading={savingManual}
                      onClick={handleSaveManual}
                    >
                      保存文案
                    </Button>
                  </Form.Item>
                </Form>
              ),
            },
          ]}
        />
      </Modal>
    </>
  );
}
