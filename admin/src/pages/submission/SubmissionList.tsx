import { useState, useEffect } from 'react';
import {
  Table, Button, Space, Card, Tag, Select, Modal, Input,
  Descriptions, message, Tabs, Form, Dropdown, Popconfirm,
} from 'antd';
import {
  CheckCircleOutlined, CloseCircleOutlined, EyeOutlined,
  EditOutlined, DeleteOutlined, MoreOutlined, PlayCircleOutlined,
} from '@ant-design/icons';
import { submissionApi } from '../../api';
import AudioPlayerModal from '../../components/AudioPlayerModal';

const { TextArea } = Input;

const statusMap: Record<string, { label: string; color: string }> = {
  pending_review: { label: '待审核', color: 'orange' },
  approved: { label: '已通过', color: 'green' },
  rejected: { label: '已驳回', color: 'red' },
  submitted: { label: '已提交', color: 'blue' },
  draft: { label: '草稿', color: 'default' },
};

export default function SubmissionList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<string | undefined>();
  const [detailModal, setDetailModal] = useState<any>(null);
  const [rejectModal, setRejectModal] = useState<any>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [activeTab, setActiveTab] = useState('all');
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);
  const [editModal, setEditModal] = useState<any>(null);
  const [editForm] = Form.useForm();
  const [editLoading, setEditLoading] = useState(false);
  const [batchDeleting, setBatchDeleting] = useState(false);
  const [audioModal, setAudioModal] = useState<{ open: boolean; src: string; title: string }>({ open: false, src: '', title: '' });

  useEffect(() => {
    loadSubmissions();
  }, [page, statusFilter, activeTab]);

  const loadSubmissions = async () => {
    setLoading(true);
    try {
      const params: any = { page, pageSize: 20 };
      if (activeTab === 'pending') {
        const res: any = await submissionApi.pendingReview(params);
        setData(res.items || []);
        setTotal(res.total || 0);
      } else {
        if (statusFilter) params.status = statusFilter;
        const res: any = await submissionApi.all(params);
        setData(res.items || []);
        setTotal(res.total || 0);
      }
    } catch {
      message.error('加载提交列表失败');
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (id: string) => {
    try {
      await submissionApi.approve(id);
      message.success('审核通过');
      loadSubmissions();
    } catch (e: any) {
      message.error(e.response?.data?.message || '操作失败');
    }
  };

  const handleReject = (record: any) => {
    setRejectModal(record);
    setRejectReason('');
  };

  const submitReject = async () => {
    if (!rejectReason.trim()) {
      message.warning('请输入驳回原因');
      return;
    }
    try {
      await submissionApi.reject(rejectModal.id, rejectReason);
      message.success('已驳回');
      setRejectModal(null);
      loadSubmissions();
    } catch (e: any) {
      message.error(e.response?.data?.message || '操作失败');
    }
  };

  const handleOpenEdit = async (record: any) => {
    try {
      const res: any = await submissionApi.detail(record.id);
      setEditModal(res);
      editForm.setFieldsValue({
        data: res.data ? JSON.stringify(res.data, null, 2) : '',
        annotations: res.annotations ? JSON.stringify(res.annotations, null, 2) : '',
      });
    } catch { message.error('加载失败'); }
  };

  const handleEditSubmit = async () => {
    setEditLoading(true);
    try {
      const values = await editForm.validateFields();
      const payload: any = {};
      if (values.data) {
        try { payload.data = JSON.parse(values.data); } catch { message.error('data 格式错误,需为有效JSON'); return; }
      }
      if (values.annotations) {
        try { payload.annotations = JSON.parse(values.annotations); } catch { message.error('annotations 格式错误,需为有效JSON'); return; }
      }
      await submissionApi.update(editModal.id, payload);
      message.success('更新成功');
      setEditModal(null);
      loadSubmissions();
    } catch (e: any) {
      if (e.response) message.error(e.response?.data?.message || '保存失败');
    } finally {
      setEditLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await submissionApi.remove(id);
      message.success('删除成功');
      loadSubmissions();
    } catch { message.error('删除失败'); }
  };

  const handleBatchDelete = async () => {
    setBatchDeleting(true);
    try {
      await submissionApi.batchDelete(selectedRowKeys as string[]);
      message.success(`成功删除 ${selectedRowKeys.length} 条`);
      setSelectedRowKeys([]);
      loadSubmissions();
    } catch { message.error('批量删除失败'); }
    finally { setBatchDeleting(false); }
  };

  const handleViewDetail = async (id: string) => {
    try {
      const res: any = await submissionApi.detail(id);
      setDetailModal(res);
    } catch {
      message.error('加载详情失败');
    }
  };

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 100,
      render: (v: string) => v.substring(0, 8),
    },
    {
      title: '任务',
      key: 'task',
      ellipsis: true,
      render: (_: any, r: any) => r.task?.title || '-',
    },
    {
      title: '采集员',
      key: 'user',
      width: 100,
      render: (_: any, r: any) => r.user?.nickname || r.user?.phone?.slice(-4) || '-',
    },
    {
      title: '归属团队',
      key: 'team',
      width: 120,
      render: (_: any, r: any) => r.task?.team?.name ?? '-',
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      width: 100,
      render: (status: string) => {
        const s = statusMap[status] || { label: status, color: 'default' };
        return <Tag color={s.color}>{s.label}</Tag>;
      },
    },
    {
      title: '文件数',
      dataIndex: 'fileIds',
      key: 'fileCount',
      width: 80,
      render: (v: string[]) => v?.length ?? 0,
    },
    {
      title: '收益',
      dataIndex: 'earnings',
      key: 'earnings',
      width: 80,
      render: (v: number) => v ? `¥${v.toFixed(2)}` : '-',
    },
    {
      title: '提交时间',
      dataIndex: 'submittedAt',
      key: 'submittedAt',
      width: 170,
      render: (v: string) => (v ? new Date(v).toLocaleString() : '-'),
    },
    {
      title: '操作',
      key: 'action',
      width: 220,
      render: (_: any, record: any) => (
        <Space size={0}>
          <Button type="link" size="small" icon={<EyeOutlined />} onClick={() => handleViewDetail(record.id)}>详情</Button>
          {record.status === 'pending_review' && (
            <Button type="link" size="small" style={{ color: '#52c41a' }} icon={<CheckCircleOutlined />} onClick={() => handleApprove(record.id)}>通过</Button>
          )}
          <Dropdown
            menu={{
              items: [
                { key: 'edit', icon: <EditOutlined />, label: '编辑', onClick: () => handleOpenEdit(record) },
                ...(record.status === 'pending_review' ? [{ key: 'reject', icon: <CloseCircleOutlined />, label: '驳回', danger: true, onClick: () => handleReject(record) }] : []),
                { key: 'delete', icon: <DeleteOutlined />, label: '删除', danger: true, onClick: () => { if (confirm('确认删除？')) handleDelete(record.id); } },
              ],
            }}
          >
            <Button type="link" size="small" icon={<MoreOutlined />} />
          </Dropdown>
        </Space>
      ),
    },
  ];

  return (
    <Card title="提交审核">
      <Tabs
        activeKey={activeTab}
        onChange={(key) => { setActiveTab(key); setPage(1); }}
        items={[
          { key: 'all', label: '全部' },
          { key: 'pending', label: '待审核' },
        ]}
      />

      {activeTab === 'all' && (
        <Space style={{ marginBottom: 16 }}>
          <Select
            placeholder="状态筛选"
            allowClear
            style={{ width: 120 }}
            value={statusFilter}
            onChange={(v) => { setStatusFilter(v); setSelectedRowKeys([]); }}
            options={Object.entries(statusMap).map(([v, { label }]) => ({ label, value: v }))}
          />
        </Space>
      )}

      <Space style={{ marginBottom: 16 }}>
        {selectedRowKeys.length > 0 && (
          <Popconfirm
            title={`确认删除选中的 ${selectedRowKeys.length} 条记录？`}
            onConfirm={handleBatchDelete}
          >
            <Button danger icon={<DeleteOutlined />} loading={batchDeleting}>
              批量删除({selectedRowKeys.length})
            </Button>
          </Popconfirm>
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
          showTotal: (t) => `共 ${t} 条`,
        }}
      />

      {/* Detail modal */}
      <Modal
        title="提交详情"
        open={!!detailModal}
        onCancel={() => setDetailModal(null)}
        footer={detailModal?.status === 'pending_review' ? (
          <Space>
            <Button onClick={() => setDetailModal(null)}>关闭</Button>
            <Button danger onClick={() => { setDetailModal(null); handleReject(detailModal); }}>
              驳回
            </Button>
            <Button type="primary" onClick={() => { setDetailModal(null); handleApprove(detailModal.id); }}>
              通过
            </Button>
          </Space>
        ) : null}
        width={700}
      >
        {detailModal && (
          <>
            <Descriptions bordered column={2} size="small">
              <Descriptions.Item label="提交ID">{detailModal.id}</Descriptions.Item>
              <Descriptions.Item label="状态">
                <Tag color={statusMap[detailModal.status]?.color}>
                  {statusMap[detailModal.status]?.label || detailModal.status}
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="任务">{detailModal.task?.title || '-'}</Descriptions.Item>
              <Descriptions.Item label="采集员">{detailModal.user?.nickname || '-'}</Descriptions.Item>
              <Descriptions.Item label="收益">{detailModal.earnings ? `¥${detailModal.earnings.toFixed(2)}` : '-'}</Descriptions.Item>
              <Descriptions.Item label="文件数">{detailModal.fileIds?.length ?? 0}</Descriptions.Item>
              <Descriptions.Item label="提交时间">
                {detailModal.submittedAt ? new Date(detailModal.submittedAt).toLocaleString() : '-'}
              </Descriptions.Item>
              <Descriptions.Item label="审核时间">
                {detailModal.reviewedAt ? new Date(detailModal.reviewedAt).toLocaleString() : '-'}
              </Descriptions.Item>
              {detailModal.rejectReason && (
                <Descriptions.Item label="驳回原因" span={2}>
                  <span style={{ color: '#ff4d4f' }}>{detailModal.rejectReason}</span>
                </Descriptions.Item>
              )}
              {detailModal.fileIds?.length > 0 && (
                <Descriptions.Item label="音频/文件预览" span={2}>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8, width: '100%' }}>
                    {detailModal.fileIds.map((fid: string, idx: number) => (
                      <div key={fid} style={{ background: '#f5f5f5', borderRadius: 8, padding: 8, width: '100%' }}>
                        <div style={{ marginBottom: 4, fontSize: 12, color: '#888' }}>文件 {idx + 1}</div>
                        <Button type="primary" size="small" icon={<PlayCircleOutlined />}
                          onClick={() => setAudioModal({ open: true, src: `/api/files/${fid}/stream`, title: `文件 ${idx + 1}` })}>试听</Button>
                      </div>
                    ))}
                  </div>
                </Descriptions.Item>
              )}
              {detailModal.data && (
                <Descriptions.Item label="采集数据" span={2}>
                  <pre style={{ margin: 0, fontSize: 12, maxHeight: 200, overflow: 'auto' }}>{JSON.stringify(detailModal.data, null, 2)}</pre>
                </Descriptions.Item>
              )}
            </Descriptions>

            {/* Quick approve/reject for pending */}
            {detailModal.status === 'pending_review' && (
              <div style={{ marginTop: 16, padding: 16, background: '#fffbe6', borderRadius: 8 }}>
                <Space>
                  <Button
                    type="primary"
                    icon={<CheckCircleOutlined />}
                    onClick={() => { setDetailModal(null); handleApprove(detailModal.id); }}
                  >
                    审核通过
                  </Button>
                  <Button
                    danger
                    icon={<CloseCircleOutlined />}
                    onClick={() => { setDetailModal(null); handleReject(detailModal); }}
                  >
                    驳回
                  </Button>
                </Space>
              </div>
            )}
          </>
        )}
      </Modal>

      {/* Reject modal */}
      <Modal
        title="驳回提交"
        open={!!rejectModal}
        onOk={submitReject}
        onCancel={() => setRejectModal(null)}
        okText="确认驳回"
        okButtonProps={{ danger: true }}
      >
        <div style={{ marginBottom: 12 }}>
          提交ID: <code>{rejectModal?.id?.substring(0, 8)}</code>
        </div>
        <TextArea
          rows={4}
          placeholder="请输入驳回原因"
          value={rejectReason}
          onChange={(e) => setRejectReason(e.target.value)}
        />
      </Modal>

      {/* Edit Modal */}
      <Modal
        title="编辑提交"
        open={!!editModal}
        onOk={handleEditSubmit}
        onCancel={() => setEditModal(null)}
        confirmLoading={editLoading}
        width={600}
      >
        <Form form={editForm} layout="vertical">
          <Form.Item name="data" label="采集数据 (JSON)">
            <Input.TextArea rows={8} placeholder='{"key": "value"}' />
          </Form.Item>
          <Form.Item name="annotations" label="标注信息 (JSON)">
            <Input.TextArea rows={4} placeholder='{"key": "value"}' />
          </Form.Item>
        </Form>
      </Modal>

      <AudioPlayerModal
        open={audioModal.open}
        onClose={() => setAudioModal({ open: false, src: '', title: '' })}
        src={audioModal.src}
        title={audioModal.title}
      />
    </Card>
  );
}
