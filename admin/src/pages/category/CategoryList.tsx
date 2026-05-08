import { useState, useEffect } from 'react';
import {
  Table, Button, Space, Card, Tag, Modal, Form, Input, Select,
  InputNumber, Switch, message,
} from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined } from '@ant-design/icons';
import { categoryApi } from '../../api';

const typeMap: Record<string, { label: string; color: string }> = {
  audio: { label: '语音', color: 'blue' },
  image: { label: '图像', color: 'green' },
  video: { label: '视频', color: 'orange' },
};

export default function CategoryList() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [editModal, setEditModal] = useState<any>(null);
  const [form] = Form.useForm();

  useEffect(() => {
    loadCategories();
  }, []);

  const loadCategories = async () => {
    setLoading(true);
    try {
      const res: any = await categoryApi.list();
      setData(Array.isArray(res) ? res : res.items || []);
    } catch {
      message.error('加载分类失败');
    } finally {
      setLoading(false);
    }
  };

  const handleCreate = () => {
    form.resetFields();
    form.setFieldsValue({ isActive: true, sortOrder: 0 });
    setEditModal({ isNew: true });
  };

  const handleEdit = (record: any) => {
    form.setFieldsValue({
      name: record.name,
      code: record.code,
      type: record.type,
      description: record.description,
      isActive: record.isActive,
      sortOrder: record.sortOrder,
    });
    setEditModal(record);
  };

  const handleSubmit = async () => {
    try {
      const values = await form.validateFields();
      if (editModal.isNew) {
        await categoryApi.create(values);
        message.success('创建成功');
      } else {
        await categoryApi.update(editModal.id, values);
        message.success('更新成功');
      }
      setEditModal(null);
      loadCategories();
    } catch (e: any) {
      if (e.errorFields) return;
      message.error(e.response?.data?.message || '操作失败');
    }
  };

  const handleDelete = (id: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '删除后不可恢复，确认删除此分类？',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await categoryApi.remove(id);
          message.success('删除成功');
          loadCategories();
        } catch {
          message.error('删除失败');
        }
      },
    });
  };

  const columns = [
    {
      title: '名称',
      dataIndex: 'name',
      key: 'name',
      render: (v: string) => <strong>{v}</strong>,
    },
    {
      title: '编码',
      dataIndex: 'code',
      key: 'code',
      render: (v: string) => <code>{v}</code>,
    },
    {
      title: '类型',
      dataIndex: 'type',
      key: 'type',
      render: (type: string) => {
        const t = typeMap[type] || { label: type, color: 'default' };
        return <Tag color={t.color}>{t.label}</Tag>;
      },
    },
    {
      title: '描述',
      dataIndex: 'description',
      key: 'description',
      ellipsis: true,
    },
    {
      title: '排序',
      dataIndex: 'sortOrder',
      key: 'sortOrder',
      width: 70,
    },
    {
      title: '状态',
      dataIndex: 'isActive',
      key: 'isActive',
      width: 80,
      render: (v: boolean) => v ? <Tag color="green">启用</Tag> : <Tag color="red">禁用</Tag>,
    },
    {
      title: '操作',
      key: 'action',
      width: 150,
      render: (_: any, record: any) => (
        <Space>
          <Button type="link" size="small" icon={<EditOutlined />} onClick={() => handleEdit(record)}>
            编辑
          </Button>
          <Button type="link" size="small" danger icon={<DeleteOutlined />} onClick={() => handleDelete(record.id)}>
            删除
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <Card
      title="分类管理"
      extra={
        <Button type="primary" icon={<PlusOutlined />} onClick={handleCreate}>
          新建分类
        </Button>
      }
    >
      <Table
        rowKey="id"
        columns={columns}
        dataSource={data}
        loading={loading}
        pagination={false}
      />

      <Modal
        title={editModal?.isNew ? '新建分类' : '编辑分类'}
        open={!!editModal}
        onOk={handleSubmit}
        onCancel={() => setEditModal(null)}
        destroyOnClose
      >
        <Form form={form} layout="vertical">
          <Form.Item name="name" label="分类名称" rules={[{ required: true }]}>
            <Input placeholder="如：普通话语音" />
          </Form.Item>
          <Form.Item name="code" label="分类编码" rules={[{ required: true }]}>
            <Input placeholder="如：mandarin_audio" disabled={!editModal?.isNew} />
          </Form.Item>
          <Form.Item name="type" label="类型" rules={[{ required: true }]}>
            <Select
              options={Object.entries(typeMap).map(([v, { label }]) => ({ label, value: v }))}
            />
          </Form.Item>
          <Form.Item name="description" label="描述">
            <Input.TextArea rows={3} />
          </Form.Item>
          <Form.Item name="sortOrder" label="排序（小号在前）">
            <InputNumber min={0} style={{ width: '100%' }} />
          </Form.Item>
          <Form.Item name="isActive" label="启用" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </Card>
  );
}
