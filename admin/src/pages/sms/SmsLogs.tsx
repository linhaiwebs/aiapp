import { useState, useEffect } from 'react';
import { Table, Card, Tag, Input, Space, Button, Badge } from 'antd';
import { SearchOutlined, ReloadOutlined, PhoneOutlined } from '@ant-design/icons';
import { smsApi } from '../../api';

export default function SmsLogs() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [phone, setPhone] = useState('');

  const loadLogs = async () => {
    setLoading(true);
    try {
      const res: any = await smsApi.getLogs({ phone: phone || undefined });
      setData(res.items || []);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadLogs();
    // Auto-refresh every 5s
    const timer = setInterval(loadLogs, 5000);
    return () => clearInterval(timer);
  }, []);

  const handleSearch = () => {
    loadLogs();
  };

  const columns = [
    {
      title: '手机号',
      dataIndex: 'phone',
      key: 'phone',
      width: 150,
      render: (v: string) => (
        <Space>
          <PhoneOutlined style={{ color: '#1890ff' }} />
          <span style={{ fontFamily: 'monospace', letterSpacing: 1 }}>{v}</span>
        </Space>
      ),
    },
    {
      title: '验证码',
      dataIndex: 'code',
      key: 'code',
      width: 120,
      render: (v: string) => (
        <span style={{
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: 700,
          color: '#1890ff',
          letterSpacing: 4,
          background: '#e6f7ff',
          padding: '2px 8px',
          borderRadius: 4,
        }}>
          {v}
        </span>
      ),
    },
    {
      title: '发送时间',
      dataIndex: 'sentAt',
      key: 'sentAt',
      width: 180,
      render: (v: string) => v ? new Date(v).toLocaleString() : '-',
    },
    {
      title: '渠道',
      dataIndex: 'provider',
      key: 'provider',
      width: 90,
      render: (v: string) => (
        <Tag color={v === 'aliyun' ? 'green' : 'orange'}>
          {v === 'aliyun' ? '阿里云' : 'Mock'}
        </Tag>
      ),
    },
    {
      title: '状态',
      key: 'status',
      width: 100,
      render: (_: any, r: any) => {
        if (r.verified) {
          return <Badge status="success" text="已验证" />;
        }
        if (r.expired) {
          return <Badge status="default" text="已过期" />;
        }
        return <Badge status="processing" text="待使用" />;
      },
    },
  ];

  return (
    <Card
      title="验证码记录"
      extra={
        <Space>
          <span style={{ color: '#999', fontSize: 12 }}>自动刷新 5s</span>
          <Button icon={<ReloadOutlined />} onClick={loadLogs}>刷新</Button>
        </Space>
      }
    >
      <Space style={{ marginBottom: 16 }}>
        <Input
          placeholder="搜索手机号"
          prefix={<SearchOutlined />}
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          onPressEnter={handleSearch}
          style={{ width: 200 }}
        />
        <Button type="primary" onClick={handleSearch}>搜索</Button>
        <Button onClick={() => { setPhone(''); loadLogs(); }}>重置</Button>
      </Space>

      <Table
        rowKey={(r) => `${r.phone}-${r.sentAt}`}
        columns={columns}
        dataSource={data}
        loading={loading}
        pagination={{ pageSize: 20, showTotal: (t) => `共 ${t} 条` }}
        size="small"
      />
    </Card>
  );
}
