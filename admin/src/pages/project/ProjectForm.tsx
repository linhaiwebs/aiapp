import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Form, Input, DatePicker, Switch, Button, Spin, message, Row, Col, Select, InputNumber } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { projectApi, userApi, teamApi } from '../../api';

export default function ProjectForm() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(!!id);
  const [users, setUsers] = useState<any[]>([]);
  const [teams, setTeams] = useState<any[]>([]);
  const isEdit = !!id;

  useEffect(() => {
    loadUsers();
    loadTeams();
    if (id) loadProject();
  }, [id]);

  const loadUsers = async () => {
    try {
      const res: any = await userApi.list({ pageSize: 200 });
      setUsers(res.items || []);
    } catch { /* ignore */ }
  };

  const loadTeams = async () => {
    try {
      const res: any = await teamApi.list({ pageSize: 200 });
      setTeams(res.items || []);
    } catch { /* ignore */ }
  };

  const loadProject = async () => {
    try {
      const res: any = await projectApi.detail(id!);
      form.setFieldsValue({
        ...res,
        startDate: res.startDate ? dayjs(res.startDate) : undefined,
        endDate: res.endDate ? dayjs(res.endDate) : undefined,
        isActive: res.isActive ?? true,
        requireSignature: res.requireSignature ?? false,
      });
    } catch {
      message.error('加载项目失败');
    } finally {
      setFetching(false);
    }
  };

  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      const data = {
        ...values,
        startDate: values.startDate?.toISOString(),
        endDate: values.endDate?.toISOString(),
      };
      if (isEdit) {
        await projectApi.update(id!, data);
        message.success('更新成功');
      } else {
        await projectApi.create(data);
        message.success('创建成功');
      }
      navigate('/projects');
    } catch (e: any) {
      message.error(e.response?.data?.message || (isEdit ? '更新失败' : '创建失败'));
    } finally {
      setLoading(false);
    }
  };

  if (fetching) return <Spin style={{ display: 'block', margin: '100px auto' }} />;

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
      <Card title={isEdit ? '编辑项目' : '新建项目'}>
        <Form
          form={form}
          layout="vertical"
          onFinish={onFinish}
          initialValues={{ isActive: true, requireSignature: false, recycleHours: 48 }}
          style={{ maxWidth: 800 }}
        >
          <Row gutter={16}>
            <Col span={12}>
              <Form.Item name="name" label="项目名称" tooltip="项目的唯一名称" rules={[{ required: true, message: '请输入项目名称' }]}>
                <Input placeholder="请输入项目名称" />
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item name="region" label="项目地区" tooltip="项目开展的地理区域，如：北京、上海">
                <Input placeholder="如：北京、上海" />
              </Form.Item>
            </Col>
          </Row>

          <Form.Item name="description" label="项目描述" tooltip="对项目目标、内容和范围的简要描述">
            <Input.TextArea rows={3} placeholder="请输入项目描述" />
          </Form.Item>

          <Row gutter={16}>
            <Col span={8}>
              <Form.Item name="startDate" label="开始日期" tooltip="项目预计开始的日期">
                <DatePicker style={{ width: '100%' }} />
              </Form.Item>
            </Col>
            <Col span={8}>
              <Form.Item name="endDate" label="结束日期" tooltip="项目预计结束的日期">
                <DatePicker style={{ width: '100%' }} />
              </Form.Item>
            </Col>
            <Col span={8}>
              <Form.Item name="department" label="部门识别方式" tooltip="用于识别参与者所属部门的标识方式">
                <Input placeholder="如：研发部" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={8}>
              <Form.Item name="teamId" label="所属团队" tooltip="项目归属于该团队，仅团队成员可处理此项目下的任务">
                <Select
                  allowClear
                  showSearch
                  placeholder="选择团队（可选）"
                  optionFilterProp="label"
                  options={teams.map((t: any) => ({ label: t.name, value: t.id }))}
                />
              </Form.Item>
            </Col>
            <Col span={8}>
              <Form.Item name="ownerId" label="负责人" tooltip="指定负责管理该项目的用户">
                <Select
                  allowClear
                  showSearch
                  placeholder="选择负责人"
                  optionFilterProp="label"
                  options={users.map((u: any) => ({ label: u.nickname || u.phone, value: u.id }))}
                />
              </Form.Item>
            </Col>
            <Col span={8}>
              <Form.Item name="acceptorId" label="验收人" tooltip="指定负责验收项目成果的用户">
                <Select
                  allowClear
                  showSearch
                  placeholder="选择验收人"
                  optionFilterProp="label"
                  options={users.map((u: any) => ({ label: u.nickname || u.phone, value: u.id }))}
                />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={8}>
              <Form.Item name="requireSignature" label="授权签名" valuePropName="checked" tooltip="开启后采集员提交时需要电子签名授权">
                <Switch checkedChildren="需要" unCheckedChildren="不需要" />
              </Form.Item>
            </Col>
            <Col span={8}>
              <Form.Item name="recycleHours" label="回收时间(小时)" tooltip="任务领取后超时未完成，系统将自动回收重新分配">
                <InputNumber min={1} style={{ width: '100%' }} placeholder="48" />
              </Form.Item>
            </Col>
            <Col span={8}>
              <Form.Item name="isActive" label="启用" valuePropName="checked" tooltip="控制项目是否处于启用状态">
                <Switch />
              </Form.Item>
            </Col>
          </Row>

          <Form.Item>
            <Button type="primary" htmlType="submit" loading={loading}>
              {isEdit ? '保存修改' : '创建项目'}
            </Button>
            <Button style={{ marginLeft: 8 }} onClick={() => navigate('/projects')}>
              取消
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
}
