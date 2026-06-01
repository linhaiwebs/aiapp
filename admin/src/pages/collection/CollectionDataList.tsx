import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { Table, Card, Tag, Space, Select, Button, Modal, Descriptions, message, Input, Form, Dropdown, Popconfirm } from 'antd';
import { EyeOutlined, PlayCircleOutlined, CheckCircleOutlined, CloseCircleOutlined, EditOutlined, DeleteOutlined, MoreOutlined } from '@ant-design/icons';
import { submissionApi } from '../../api';
import AudioPlayerModal from '../../components/AudioPlayerModal';

const typeLabels: Record<string, string> = {
  text: '文本采集',
  audio: '语音采集',
  video: '视频采集',
  image: '图像采集',
};

const statusMap: Record<string, { label: string; color: string }> = {
  draft: { label: '草稿', color: 'default' },
  submitted: { label: '已提交', color: 'blue' },
  qc_processing: { label: '质检中', color: 'processing' },
  qc_passed: { label: '质检通过', color: 'cyan' },
  qc_failed: { label: '质检未通过', color: 'warning' },
  pending_review: { label: '待审核', color: 'orange' },
  approved: { label: '审核通过', color: 'green' },
  rejected: { label: '已驳回', color: 'red' },
};

export default function CollectionDataList() {
  const { type } = useParams<{ type: string }>();
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<string | undefined>();
  const [detailModal, setDetailModal] = useState<any>(null);
  const [rejectModal, setRejectModal] = useState<any>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([]);
  const [editModal, setEditModal] = useState<any>(null);
  const [editForm] = Form.useForm();
  const [editLoading, setEditLoading] = useState(false);
  const [batchDeleting, setBatchDeleting] = useState(false);
  const [audioModal, setAudioModal] = useState<{ open: boolean; src: string; fileId: string; title: string }>({ open: false, src: '', fileId: '', title: '' });

  useEffect(() => {
    loadSubmissions();
  }, [type, page, statusFilter]);

  const loadSubmissions = async () => {
    setLoading(true);
    try {
      const params: any = { page, pageSize: 20 };
      if (statusFilter) params.status = statusFilter;
      if (type) params.taskType = type;
      const res: any = await submissionApi.all(params);
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch {
      message.error('加载数据失败');
    } finally {
      setLoading(false);
    }
  };

  const handleViewDetail = async (id: string) => {
    try {
      const res: any = await submissionApi.detail(id);
      setDetailModal(res);
    } catch {
      message.error('加载详情失败');
    }
  };

  const handleApprove = async (id: string) => {
    try {
      await submissionApi.approve(id);
      message.success('审核通过');
      loadSubmissions();
      setDetailModal(null);
    } catch { message.error('操作失败'); }
  };

  const handleReject = async () => {
    if (!rejectReason.trim()) { message.warning('请输入驳回原因'); return; }
    try {
      await submissionApi.reject(rejectModal.id, rejectReason);
      message.success('已驳回');
      setRejectModal(null);
      setRejectReason('');
      loadSubmissions();
      setDetailModal(null);
    } catch { message.error('操作失败'); }
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

  const getFileStreamUrl = (fileId: string) => `/api/files/${fileId}/stream`;

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 80,
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
      title: '联系方式',
      key: 'contact',
      width: 130,
      render: (_: any, r: any) => r.user?.phone || r.user?.email || '-',
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
      width: 70,
      render: (v: string[]) => v?.length ?? 0,
    },
    {
      title: '时长',
      key: 'duration',
      width: 90,
      render: (_: any, r: any) => {
        const dur = r.data?.duration;
        if (!dur) return '-';
        if (dur < 60) return `${dur}秒`;
        return `${Math.floor(dur / 60)}分${dur % 60}秒`;
      },
    },
    {
      title: '设备型号',
      key: 'device',
      width: 110,
      render: (_: any, r: any) => r.data?.deviceModel || r.data?.device || '-',
    },
    {
      title: '提交时间',
      dataIndex: 'submittedAt',
      key: 'submittedAt',
      width: 160,
      render: (v: string) => (v ? new Date(v).toLocaleString() : '-'),
    },
    {
      title: '操作',
      key: 'action',
      width: 260,
      render: (_: any, record: any) => (
        <Space size={0}>
          <Button type="link" size="small" icon={<EyeOutlined />} onClick={() => handleViewDetail(record.id)}>详情</Button>
          {(type === 'audio' || record.task?.type === 'audio') && record.fileIds?.length > 0 && (
            <Button type="link" size="small" icon={<PlayCircleOutlined />}
              onClick={() => setAudioModal({ open: true, src: getFileStreamUrl(record.fileIds[0]), fileId: record.fileIds[0], title: `文件 - ${record.id?.substring(0, 8)}` })}>试听</Button>
          )}
          {(type === 'video' || record.task?.type === 'video') && record.fileIds?.length > 0 && (
            <Button type="link" size="small" icon={<PlayCircleOutlined />}
              onClick={() => window.open(getFileStreamUrl(record.fileIds[0]), '_blank')}>预览</Button>
          )}
          {record.status === 'pending_review' && (
            <Button type="link" size="small" icon={<CheckCircleOutlined />} style={{ color: '#52c41a' }} onClick={() => handleApprove(record.id)}>通过</Button>
          )}
          <Dropdown
            menu={{
              items: [
                { key: 'edit', icon: <EditOutlined />, label: '编辑', onClick: () => handleOpenEdit(record) },
                ...(record.status === 'pending_review' ? [{ key: 'reject', icon: <CloseCircleOutlined />, label: '驳回', danger: true, onClick: () => { setRejectModal(record); setRejectReason(''); } }] : []),
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
    <Card title={typeLabels[type || 'text'] || '采集数据'}>
      <Space style={{ marginBottom: 16 }}>
        <Select
          placeholder="状态筛选"
          allowClear
          style={{ width: 120 }}
          value={statusFilter}
          onChange={(v) => { setStatusFilter(v); setSelectedRowKeys([]); }}
          options={Object.entries(statusMap).map(([v, { label }]) => ({ label, value: v }))}
        />
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

      {/* Detail Modal */}
      <Modal
        title="采集详情"
        open={!!detailModal}
        onCancel={() => setDetailModal(null)}
        footer={
          detailModal?.status === 'pending_review' ? (
            <Space>
              <Button onClick={() => setDetailModal(null)}>关闭</Button>
              <Button type="primary" style={{ background: '#52c41a' }} icon={<CheckCircleOutlined />}
                onClick={() => handleApprove(detailModal.id)}>通过</Button>
              <Button danger icon={<CloseCircleOutlined />}
                onClick={() => { setRejectModal(detailModal); setRejectReason(''); setDetailModal(null); }}>驳回</Button>
            </Space>
          ) : <Button onClick={() => setDetailModal(null)}>关闭</Button>
        }
        width={700}
      >
        {detailModal && (
          <Descriptions bordered column={2} size="small">
            <Descriptions.Item label="提交ID">{detailModal.id}</Descriptions.Item>
            <Descriptions.Item label="状态">
              <Tag color={statusMap[detailModal.status]?.color}>
                {statusMap[detailModal.status]?.label || detailModal.status}
              </Tag>
            </Descriptions.Item>
            <Descriptions.Item label="任务">{detailModal.task?.title || '-'}</Descriptions.Item>
            <Descriptions.Item label="采集员">{detailModal.user?.nickname || '-'}</Descriptions.Item>
            <Descriptions.Item label="联系方式">{detailModal.user?.phone || detailModal.user?.email || '-'}</Descriptions.Item>
            <Descriptions.Item label="设备型号">{detailModal.data?.deviceModel || '-'}</Descriptions.Item>
            <Descriptions.Item label="文件数">{detailModal.fileIds?.length ?? 0}</Descriptions.Item>
            <Descriptions.Item label="质检分数">{detailModal.qcScore ?? '-'}</Descriptions.Item>
            <Descriptions.Item label="录音时长">
              {detailModal.data?.duration ? `${Math.floor(detailModal.data.duration / 60)}分${detailModal.data.duration % 60}秒` : '-'}
            </Descriptions.Item>
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
            {(detailModal.task?.type === 'text' || type === 'text') && detailModal.data?.content && (
              <Descriptions.Item label="文本内容" span={2}>
                <pre style={{ margin: 0, fontSize: 12, maxHeight: 200, overflow: 'auto', whiteSpace: 'pre-wrap' }}>
                  {detailModal.data.content}
                </pre>
              </Descriptions.Item>
            )}
            {detailModal.fileIds?.length > 0 && (
              <Descriptions.Item label={type === 'video' ? '视频播放' : '音频/文件预览'} span={2}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 12, width: '100%' }}>
                  {detailModal.fileIds.map((fid: string, idx: number) => (
                    <div key={fid} style={{ width: '100%' }}>
                      <div style={{ marginBottom: 4, fontSize: 12, color: '#888' }}>文件 {idx + 1}</div>
                      {type === 'video' ? (
                        <video controls src={getFileStreamUrl(fid)} style={{ width: '100%', maxHeight: 240, borderRadius: 6 }} />
                      ) : type === 'image' ? (
                        <img src={getFileStreamUrl(fid)} alt={`文件 ${idx + 1}`} style={{ maxWidth: '100%', maxHeight: 300, borderRadius: 6 }} />
                      ) : (
                        <div style={{ background: '#f5f5f5', borderRadius: 8, padding: 12 }}>
                          <Button type="primary" size="small" icon={<PlayCircleOutlined />}
                            onClick={() => setAudioModal({ open: true, src: getFileStreamUrl(fid), fileId: fid, title: `文件 ${idx + 1}` })}>试听</Button>
                        </div>
                      )}
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
        )}
      </Modal>

      {/* Reject Modal */}
      <Modal title="驳回原因" open={!!rejectModal} onOk={handleReject} onCancel={() => setRejectModal(null)}>
        <Input.TextArea rows={3} value={rejectReason} onChange={e => setRejectReason(e.target.value)} placeholder="请输入驳回原因" />
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
        onClose={() => setAudioModal({ open: false, src: '', fileId: '', title: '' })}
        src={audioModal.src}
        fileId={audioModal.fileId}
        title={audioModal.title}
      />
    </Card>
  );
}
