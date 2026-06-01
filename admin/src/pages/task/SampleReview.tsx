import { useState, useEffect, useCallback } from 'react';
import { Table, Button, Space, Card, message, Modal, Input } from 'antd';
import { CheckOutlined, CloseOutlined, PlayCircleOutlined } from '@ant-design/icons';
import { taskApi } from '../../api';
import AudioPlayerModal from '../../components/AudioPlayerModal';

export default function SampleReview() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [rejectModal, setRejectModal] = useState<any>(null);
  const [reason, setReason] = useState('');
  const [audioUrls, setAudioUrls] = useState<Record<string, string>>({});
  const [audioModal, setAudioModal] = useState<{ open: boolean; src: string; fileId: string; title: string }>({ open: false, src: '', fileId: '', title: '' });

  useEffect(() => { loadData(); }, [page]);

  const loadData = async () => {
    setLoading(true);
    try {
      const res: any = await taskApi.sampleClaims({ page, pageSize: 20 });
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch { message.error('加载失败'); }
    finally { setLoading(false); }
  };

  const handleApprove = async (claimId: string) => {
    try { await taskApi.approveSample(claimId); message.success('已通过'); loadData(); }
    catch { message.error('操作失败'); }
  };

  const handleReject = async () => {
    if (!reason.trim()) { message.warning('请输入驳回原因'); return; }
    try { await taskApi.rejectSample(rejectModal.id, reason); message.success('已驳回'); setRejectModal(null); setReason(''); loadData(); }
    catch { message.error('操作失败'); }
  };

  const ensureUrl = useCallback(async (fileId: string) => {
    if (audioUrls[fileId]) return audioUrls[fileId];
    try {
      const res: any = await taskApi.getFileUrl(fileId);
      const url = res?.url || `/api/files/${fileId}/stream`;
      setAudioUrls((prev) => ({ ...prev, [fileId]: url }));
      return url;
    } catch {
      return `/api/files/${fileId}/stream`;
    }
  }, [audioUrls]);

  const columns = [
    { title: '申请人', key: 'user', render: (_: any, r: any) => r.user?.nickname || r.user?.phone || r.userId?.substring(0, 8) },
    { title: '手机号', key: 'phone', width: 120, render: (_: any, r: any) => r.user?.phone || '-' },
    { title: '任务', key: 'task', ellipsis: true, render: (_: any, r: any) => r.task?.title || '-' },
    { title: '申请时间', dataIndex: 'createdAt', width: 160, render: (v: string) => v ? new Date(v).toLocaleString() : '-' },
    {
      title: '样音', key: 'sample', width: 280,
      render: (_: any, r: any) => (
        <SampleAudioCell
          fileId={r.sampleFileId}
          ensureUrl={ensureUrl}
          onPlay={(src, fid, t) => setAudioModal({ open: true, src, fileId: fid, title: t })}
        />
      ),
    },
    {
      title: '操作', key: 'action', width: 140,
      render: (_: any, r: any) => (
        <Space>
          <Button type="primary" size="small" icon={<CheckOutlined />} onClick={() => handleApprove(r.id)}>通过</Button>
          <Button danger size="small" icon={<CloseOutlined />} onClick={() => { setRejectModal(r); setReason(''); }}>驳回</Button>
        </Space>
      ),
    },
  ];

  return (
    <>
      <Card title="采样审核" extra={<Button onClick={loadData}>刷新</Button>}>
        {total > 0 && <div style={{ marginBottom: 16, color: '#fa8c16' }}>待审核 <b>{total}</b> 条采样申请</div>}
        <Table rowKey="id" columns={columns} dataSource={data} loading={loading}
          pagination={{ current: page, total, pageSize: 20, onChange: setPage }} />
      </Card>
      <Modal title="驳回采样" open={!!rejectModal} onOk={handleReject} onCancel={() => setRejectModal(null)}>
        <Input.TextArea rows={3} value={reason} onChange={e => setReason(e.target.value)} placeholder="请输入驳回原因" />
      </Modal>
      <AudioPlayerModal
        open={audioModal.open}
        onClose={() => setAudioModal({ open: false, src: '', fileId: '', title: '' })}
        src={audioModal.src}
        fileId={audioModal.fileId}
        title={audioModal.title}
      />
    </>
  );
}

function SampleAudioCell({ fileId, ensureUrl, onPlay }: { fileId?: string; ensureUrl: (id: string) => Promise<string>; onPlay: (src: string, fileId: string, title: string) => void }) {
  const [url, setUrl] = useState<string>('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!fileId) return;
    setLoading(true);
    ensureUrl(fileId).then((u) => { setUrl(u); setLoading(false); });
  }, [fileId, ensureUrl]);

  if (!fileId) return <span style={{ color: '#999' }}>未上传</span>;
  if (loading || !url) return <span style={{ color: '#999' }}>加载中...</span>;
  return <Button type="link" size="small" icon={<PlayCircleOutlined />} onClick={() => onPlay(url, fileId!, `样音 - ${fileId!.substring(0, 8)}`)}>试听</Button>;
}
