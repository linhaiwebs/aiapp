import { useState, useEffect } from 'react';
import {
  Table, Button, Space, Card, Tag, Input, Modal,
  Form, message, List, Select,
} from 'antd';
import {
  PlusOutlined, TeamOutlined, UserAddOutlined,
} from '@ant-design/icons';
import { teamApi, userApi } from '../../api';

export default function TeamList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [keyword, setKeyword] = useState('');
  const [createModal, setCreateModal] = useState(false);
  const [editModal, setEditModal] = useState<any>(null);
  const [memberModal, setMemberModal] = useState<any>(null);
  const [members, setMembers] = useState<any[]>([]);
  const [inviteModal, setInviteModal] = useState<any>(null);
  const [users, setUsers] = useState<any[]>([]);
  const [addMemberModal, setAddMemberModal] = useState<any>(null);
  const [form] = Form.useForm();
  const [inviteForm] = Form.useForm();
  const [memberForm] = Form.useForm();

  useEffect(() => { loadTeams(); loadUsers(); }, [page]);

  const loadTeams = async () => {
    setLoading(true);
    try {
      const res: any = await teamApi.list({ page, pageSize: 20, keyword: keyword || undefined });
      setData(res.items || []);
      setTotal(res.total || 0);
    } catch { message.error('加载团队失败'); }
    finally { setLoading(false); }
  };

  const loadUsers = async () => {
    try {
      const res: any = await userApi.list({ pageSize: 200 });
      setUsers(res.items || []);
    } catch { /* ignore */ }
  };

  const handleCreate = async () => {
    try {
      const values = await form.validateFields();
      await teamApi.create(values);
      message.success('创建成功');
      setCreateModal(false);
      form.resetFields();
      loadTeams();
    } catch (e: any) {
      if (e.response) message.error(e.response?.data?.message || '创建失败');
    }
  };

  const handleEdit = async () => {
    try {
      const values = await form.validateFields();
      await teamApi.update(editModal.id, values);
      message.success('更新成功');
      setEditModal(null);
      form.resetFields();
      loadTeams();
    } catch (e: any) {
      if (e.response) message.error(e.response?.data?.message || '更新失败');
    }
  };

  const handleDelete = async (id: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '删除团队将同时移除所有成员关系，确定删除？',
      onOk: async () => {
        try { await teamApi.remove(id); message.success('删除成功'); loadTeams(); }
        catch { message.error('删除失败'); }
      },
    });
  };

  const loadMembers = async (teamId: string) => {
    try {
      const res: any = await teamApi.getMembers(teamId);
      setMembers(Array.isArray(res) ? res : []);
    } catch { message.error('加载成员失败'); }
  };

  const handleViewMembers = (team: any) => {
    setMemberModal(team);
    loadMembers(team.id);
  };

  const handleAddMember = async () => {
    try {
      const values = await memberForm.validateFields();
      await teamApi.addMember(addMemberModal.id, values);
      message.success('添加成功');
      setAddMemberModal(null);
      memberForm.resetFields();
      loadMembers(addMemberModal.id);
    } catch (e: any) {
      if (e.response) message.error(e.response?.data?.message || '添加失败');
    }
  };

  const handleInvite = async () => {
    try {
      const values = await inviteForm.validateFields();
      await teamApi.inviteMember(inviteModal.id, values);
      message.success('邀请成功');
      setInviteModal(null);
      inviteForm.resetFields();
      loadMembers(inviteModal.id);
    } catch (e: any) {
      if (e.response) message.error(e.response?.data?.message || '邀请失败');
    }
  };

  const handleRemoveMember = async (teamId: string, memberId: string) => {
    try { await teamApi.removeMember(teamId, memberId); message.success('已移除'); loadMembers(teamId); }
    catch { message.error('移除失败'); }
  };

  const columns = [
    { title: '团队名称', dataIndex: 'name', key: 'name', render: (v: string) => <Space><TeamOutlined />{v}</Space> },
    { title: '描述', dataIndex: 'description', key: 'description', ellipsis: true },
    { title: '负责人', dataIndex: 'leaderName', key: 'leaderName', render: (v: string) => v || '-' },
    { title: '口令', dataIndex: 'joinCode', key: 'joinCode', width: 110, render: (v: string) => (
      <span style={{ fontFamily: 'monospace', fontSize: 14, fontWeight: 700, color: '#1890ff', letterSpacing: 2 }}>{v}</span>
    )},
    { title: '成员数', key: 'memberCount', width: 80, render: (_: any, r: any) => r.members?.length ?? 0 },
    { title: '状态', dataIndex: 'isActive', key: 'isActive', width: 80, render: (v: boolean) => <Tag color={v ? 'green' : 'default'}>{v ? '启用' : '禁用'}</Tag> },
    { title: '创建时间', dataIndex: 'createdAt', key: 'createdAt', width: 170, render: (v: string) => v ? new Date(v).toLocaleString() : '-' },
    {
      title: '操作', key: 'action', width: 280,
      render: (_: any, record: any) => (
        <Space size="small">
          <Button type="link" size="small" onClick={() => handleViewMembers(record)}>成员</Button>
          <Button type="link" size="small" onClick={() => { form.setFieldsValue(record); setEditModal(record); }}>编辑</Button>
          <Button type="link" size="small" danger onClick={() => handleDelete(record.id)}>删除</Button>
        </Space>
      ),
    },
  ];

  return (
    <Card title="团队管理">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input placeholder="搜索团队名称" value={keyword} onChange={e => setKeyword(e.target.value)} onPressEnter={loadTeams} style={{ width: 200 }} />
        <Button type="primary" icon={<PlusOutlined />} onClick={() => { form.resetFields(); setCreateModal(true); }}>新建团队</Button>
      </Space>
      <Table rowKey="id" columns={columns} dataSource={data} loading={loading}
        pagination={{ current: page, total, pageSize: 20, onChange: setPage, showTotal: (t) => `共 ${t} 条` }} />

      <Modal title={editModal ? '编辑团队' : '新建团队'} open={createModal || !!editModal}
        onOk={editModal ? handleEdit : handleCreate}
        onCancel={() => { setCreateModal(false); setEditModal(null); form.resetFields(); }}>
        <Form form={form} layout="vertical">
          <Form.Item name="name" label="团队名称" rules={[{ required: true }]}><Input placeholder="请输入团队名称" /></Form.Item>
          <Form.Item name="description" label="描述"><Input.TextArea rows={3} /></Form.Item>
          <Form.Item name="leaderName" label="负责人名称"><Input placeholder="负责人名称" /></Form.Item>
        </Form>
      </Modal>

      <Modal title={`团队成员 - ${memberModal?.name || ''}`} open={!!memberModal}
        onCancel={() => setMemberModal(null)} footer={null} width={640}>
        <Space style={{ marginBottom: 16 }}>
          <Button icon={<UserAddOutlined />} onClick={() => { memberForm.resetFields(); setAddMemberModal(memberModal); }}>添加成员</Button>
          <Button onClick={() => { inviteForm.resetFields(); setInviteModal(memberModal); }}>邀请新人</Button>
        </Space>
        <List dataSource={members} renderItem={(m: any) => (
          <List.Item actions={[<Button type="link" danger size="small" onClick={() => handleRemoveMember(memberModal.id, m.id)}>移除</Button>]}>
            <List.Item.Meta
              title={<Space>{m.userName || m.phone || m.email}<Tag color={m.role === 'leader' ? 'orange' : 'blue'}>{m.role === 'leader' ? '负责人' : '成员'}</Tag></Space>}
              description={`${m.phone || '-'} | ${m.email || '-'}`}
            />
          </List.Item>
        )} />
      </Modal>

      <Modal title="添加成员" open={!!addMemberModal} onOk={handleAddMember} onCancel={() => setAddMemberModal(null)}>
        <Form form={memberForm} layout="vertical">
          <Form.Item name="userId" label="选择用户" rules={[{ required: true }]}>
            <Select showSearch placeholder="选择用户" optionFilterProp="label"
              options={users.map((u: any) => ({ label: `${u.nickname || u.phone} (${u.phone})`, value: u.id }))} />
          </Form.Item>
          <Form.Item name="role" label="角色">
            <Select options={[{ label: '成员', value: 'member' }, { label: '负责人', value: 'leader' }]} />
          </Form.Item>
        </Form>
      </Modal>

      <Modal title="邀请新成员" open={!!inviteModal} onOk={handleInvite} onCancel={() => setInviteModal(null)}>
        <Form form={inviteForm} layout="vertical">
          <Form.Item name="contact" label="手机号或邮箱" rules={[{ required: true }]}><Input placeholder="输入手机号或邮箱" /></Form.Item>
          <Form.Item name="userName" label="用户名"><Input placeholder="可选" /></Form.Item>
        </Form>
      </Modal>
    </Card>
  );
}
