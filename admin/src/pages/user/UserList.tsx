import { useState, useEffect } from 'react';
import {
  Table, Button, Space, Card, Tag, Select, Input, Modal,
  Descriptions, Form, InputNumber, message, Avatar, Badge,
} from 'antd';
import {
  UserOutlined, SearchOutlined, StopOutlined, CheckCircleOutlined,
  PlusOutlined, UserAddOutlined,
} from '@ant-design/icons';
import { userApi } from '../../api';

const statusMap: Record<string, { label: string; color: string }> = {
  active: { label: '正常', color: 'green' },
  blacklisted: { label: '封禁', color: 'red' },
  inactive: { label: '未激活', color: 'default' },
};

const roleMap: Record<string, { label: string; color: string }> = {
  member: { label: '会员', color: 'blue' },
  leader: { label: '团长', color: 'orange' },
  super_admin: { label: '超级管理员', color: 'red' },
};

export default function UserList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<string | undefined>();
  const [roleFilter, setRoleFilter] = useState<string | undefined>();
  const [keyword, setKeyword] = useState('');
  const [editModal, setEditModal] = useState<any>(null);
  const [detailModal, setDetailModal] = useState<any>(null);
  const [createModal, setCreateModal] = useState(false);
  const [inviteModal, setInviteModal] = useState(false);
  const [form] = Form.useForm();
  const [createForm] = Form.useForm();
  const [inviteForm] = Form.useForm();

  useEffect(() => {
    loadUsers();
  }, [page, statusFilter, roleFilter]);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const res: any = await userApi.list({
        page,
        pageSize: 20,
        status: statusFilter,
        role: roleFilter,
        keyword: keyword || undefined,
      });
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch {
      message.error('加载用户失败');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    setPage(1);
    loadUsers();
  };

  const handleStatusToggle = async (user: any) => {
    const newStatus = user.status === 'active' ? 'blacklisted' : 'active';
    Modal.confirm({
      title: newStatus === 'blacklisted' ? '确认封禁' : '确认解封',
      content: newStatus === 'blacklisted'
        ? `封禁用户 ${user.nickname || user.phone}？`
        : `解封用户 ${user.nickname || user.phone}？`,
      onOk: async () => {
        try {
          await userApi.updateStatus(user.id, newStatus);
          message.success(newStatus === 'blacklisted' ? '已封禁' : '已解封');
          loadUsers();
        } catch {
          message.error('操作失败');
        }
      },
    });
  };

  const handleEdit = (user: any) => {
    form.setFieldsValue({
      nickname: user.nickname,
      role: user.role,
      qualityScore: user.qualityScore,
      balance: user.balance,
      companyName: user.companyName,
    });
    setEditModal(user);
  };

  const handleEditSubmit = async () => {
    try {
      const values = await form.validateFields();
      await userApi.update(editModal.id, values);
      message.success('更新成功');
      setEditModal(null);
      loadUsers();
    } catch {
      message.error('更新失败');
    }
  };

  const handleViewDetail = async (user: any) => {
    try {
      const detail: any = await userApi.detail(user.id);
      setDetailModal(detail);
    } catch {
      message.error('加载详情失败');
    }
  };

  const handleCreate = async () => {
    try {
      const values = await createForm.validateFields();
      await userApi.create(values);
      message.success('创建成功');
      setCreateModal(false);
      createForm.resetFields();
      loadUsers();
    } catch (e: any) {
      if (e.response) message.error(e.response?.data?.message || '创建失败');
    }
  };

  const handleInvite = async () => {
    try {
      const values = await inviteForm.validateFields();
      await userApi.invite(values);
      message.success('邀请已发送');
      setInviteModal(false);
      inviteForm.resetFields();
      loadUsers();
    } catch (e: any) {
      if (e.response) message.error(e.response?.data?.message || '邀请失败');
    }
  };

  const columns = [
    {
      title: '用户',
      key: 'user',
      render: (_: any, r: any) => (
        <Space>
          <Avatar size="small" icon={<UserOutlined />} src={r.avatar} />
          <div>
            <div style={{ fontWeight: 500 }}>{r.nickname || '-'}</div>
            <div style={{ fontSize: 12, color: '#999' }}>{r.phone}</div>
          </div>
        </Space>
      ),
    },
    {
      title: '角色',
      dataIndex: 'role',
      key: 'role',
      width: 100,
      render: (role: string) => {
        const r = roleMap[role] || { label: role, color: 'default' };
        return <Tag color={r.color}>{r.label}</Tag>;
      },
    },
    {
      title: '企业名',
      dataIndex: 'companyName',
      key: 'companyName',
      width: 120,
      render: (v: string) => v || '-',
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      width: 80,
      render: (status: string) => {
        const s = statusMap[status] || { label: status, color: 'default' };
        return <Badge status={status === 'active' ? 'success' : status === 'blacklisted' ? 'error' : 'default'} text={s.label} />;
      },
    },
    {
      title: '质量分',
      dataIndex: 'qualityScore',
      key: 'qualityScore',
      width: 80,
      render: (v: any) => {
        const score = Number(v) || 100;
        return (
          <span style={{ color: score >= 80 ? '#52c41a' : score >= 60 ? '#fa8c16' : '#ff4d4f' }}>
            {score}
          </span>
        );
      },
    },
    {
      title: '余额',
      dataIndex: 'balance',
      key: 'balance',
      width: 100,
      render: (v: any) => `¥${Number(v ?? 0).toFixed(2)}`,
    },
    {
      title: '实名',
      dataIndex: 'isRealNameVerified',
      key: 'verified',
      width: 70,
      render: (v: boolean) => v ? <Tag color="green" icon={<CheckCircleOutlined />}>已认证</Tag> : <Tag>未认证</Tag>,
    },
    {
      title: '注册时间',
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
        <Space size="small">
          <Button type="link" size="small" onClick={() => handleViewDetail(record)}>
            详情
          </Button>
          <Button type="link" size="small" onClick={() => handleEdit(record)}>
            编辑
          </Button>
          <Button
            type="link"
            size="small"
            danger={record.status === 'active'}
            icon={record.status === 'active' ? <StopOutlined /> : <CheckCircleOutlined />}
            onClick={() => handleStatusToggle(record)}
          >
            {record.status === 'active' ? '封禁' : '解封'}
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <Card title="用户管理">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="搜索手机号/昵称"
          prefix={<SearchOutlined />}
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          onPressEnter={handleSearch}
          style={{ width: 200 }}
        />
        <Select
          placeholder="角色"
          allowClear
          style={{ width: 120 }}
          value={roleFilter}
          onChange={setRoleFilter}
          options={Object.entries(roleMap).map(([v, { label }]) => ({ label, value: v }))}
        />
        <Select
          placeholder="状态"
          allowClear
          style={{ width: 120 }}
          value={statusFilter}
          onChange={setStatusFilter}
          options={Object.entries(statusMap).map(([v, { label }]) => ({ label, value: v }))}
        />
        <Button type="primary" onClick={handleSearch}>搜索</Button>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => { createForm.resetFields(); setCreateModal(true); }}>添加账号</Button>
        <Button icon={<UserAddOutlined />} onClick={() => { inviteForm.resetFields(); setInviteModal(true); }}>邀请新成员</Button>
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
          showTotal: (t) => `共 ${t} 条`,
        }}
      />

      {/* Detail modal */}
      <Modal
        title="用户详情"
        open={!!detailModal}
        onCancel={() => setDetailModal(null)}
        footer={null}
        width={640}
      >
        {detailModal && (
          <Descriptions bordered column={2} size="small">
            <Descriptions.Item label="ID">{detailModal.id}</Descriptions.Item>
            <Descriptions.Item label="手机号">{detailModal.phone}</Descriptions.Item>
            <Descriptions.Item label="昵称">{detailModal.nickname}</Descriptions.Item>
            <Descriptions.Item label="角色">
              <Tag color={roleMap[detailModal.role]?.color}>{roleMap[detailModal.role]?.label || detailModal.role}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="企业名">{detailModal.companyName || '-'}</Descriptions.Item>
            <Descriptions.Item label="状态">
              <Tag color={statusMap[detailModal.status]?.color}>{statusMap[detailModal.status]?.label || detailModal.status}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="质量分">{Number(detailModal.qualityScore) || 100}</Descriptions.Item>
            <Descriptions.Item label="余额">¥{Number(detailModal.balance ?? 0).toFixed(2)}</Descriptions.Item>
            <Descriptions.Item label="冻结余额">¥{Number(detailModal.frozenBalance ?? 0).toFixed(2)}</Descriptions.Item>
            <Descriptions.Item label="累计收入">¥{Number(detailModal.totalEarnings ?? 0).toFixed(2)}</Descriptions.Item>
            <Descriptions.Item label="实名认证">{detailModal.isRealNameVerified ? '已认证' : '未认证'}</Descriptions.Item>
            {detailModal.profile && (
              <>
                <Descriptions.Item label="真实姓名">{detailModal.profile.realName || '-'}</Descriptions.Item>
                <Descriptions.Item label="身份证">{detailModal.profile.idCardNumber || '-'}</Descriptions.Item>
                <Descriptions.Item label="省份">{detailModal.profile.province || '-'}</Descriptions.Item>
                <Descriptions.Item label="城市">{detailModal.profile.city || '-'}</Descriptions.Item>
              </>
            )}
            <Descriptions.Item label="注册时间" span={2}>
              {detailModal.createdAt ? new Date(detailModal.createdAt).toLocaleString() : '-'}
            </Descriptions.Item>
          </Descriptions>
        )}
      </Modal>

      {/* Edit modal */}
      <Modal
        title="编辑用户"
        open={!!editModal}
        onOk={handleEditSubmit}
        onCancel={() => setEditModal(null)}
      >
        <Form form={form} layout="vertical">
          <Form.Item name="nickname" label="昵称">
            <Input />
          </Form.Item>
          <Form.Item name="role" label="角色">
            <Select
              options={Object.entries(roleMap).map(([v, { label }]) => ({ label, value: v }))}
            />
          </Form.Item>
          <Form.Item name="qualityScore" label="质量分">
            <InputNumber min={0} max={100} style={{ width: '100%' }} />
          </Form.Item>
          <Form.Item name="balance" label="余额">
            <InputNumber min={0} step={0.01} style={{ width: '100%' }} />
          </Form.Item>
          <Form.Item name="companyName" label="企业名">
            <Input placeholder="团长专有，选填" />
          </Form.Item>
        </Form>
      </Modal>

      {/* Create user modal */}
      <Modal title="添加账号" open={createModal} onOk={handleCreate} onCancel={() => setCreateModal(false)}>
        <Form form={createForm} layout="vertical">
          <Form.Item name="phone" label="手机号" rules={[{ required: true, message: '请输入手机号' }]}>
            <Input placeholder="手机号" />
          </Form.Item>
          <Form.Item name="password" label="密码" rules={[{ required: true, message: '请输入密码' }]}>
            <Input.Password placeholder="密码" />
          </Form.Item>
          <Form.Item name="nickname" label="昵称">
            <Input placeholder="昵称（可选）" />
          </Form.Item>
          <Form.Item name="role" label="角色" initialValue="member">
            <Select options={Object.entries(roleMap).map(([v, { label }]) => ({ label, value: v }))} />
          </Form.Item>
          <Form.Item name="companyName" label="企业名">
            <Input placeholder="团长专有，选填" />
          </Form.Item>
        </Form>
      </Modal>

      {/* Invite user modal */}
      <Modal title="邀请新成员" open={inviteModal} onOk={handleInvite} onCancel={() => setInviteModal(false)}>
        <Form form={inviteForm} layout="vertical">
          <Form.Item name="contact" label="手机号或邮箱" rules={[{ required: true, message: '请输入手机号或邮箱' }]}>
            <Input placeholder="输入手机号或邮箱" />
          </Form.Item>
          <Form.Item name="role" label="指定角色" initialValue="member">
            <Select options={Object.entries(roleMap).map(([v, { label }]) => ({ label, value: v }))} />
          </Form.Item>
          <Form.Item name="message" label="邀请信息">
            <Input.TextArea rows={2} placeholder="可选邀请信息" />
          </Form.Item>
        </Form>
      </Modal>
    </Card>
  );
}
