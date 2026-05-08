import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Form, Input, Select, InputNumber, DatePicker, Button, Spin, message, Row, Col, Switch, Divider, Tabs } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { taskApi, projectApi, categoryApi, textCollectionApi } from '../../api';

export default function TaskForm() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(!!id);
  const [projects, setProjects] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [taskType, setTaskType] = useState<string>('audio');
  const [textContent, setTextContent] = useState('');
  const [savingText, setSavingText] = useState(false);
  const isEdit = !!id;

  useEffect(() => {
    loadOptions();
    if (id) loadTask();
  }, [id]);

  const loadOptions = async () => {
    try {
      const [projRes, catRes]: any[] = await Promise.all([
        projectApi.list({ pageSize: 100 }),
        categoryApi.list(),
      ]);
      setProjects(projRes.items || []);
      setCategories(Array.isArray(catRes) ? catRes : catRes.items || []);
    } catch {
      // Ignore
    }
  };

  const loadTask = async () => {
    try {
      const res: any = await taskApi.detail(id!);
      form.setFieldsValue({
        ...res,
        deadline: res.deadline ? dayjs(res.deadline) : undefined,
        categoryId: res.category?.id,
        projectId: res.project?.id,
      });
      setTaskType(res.type || 'audio');
    } catch {
      message.error('加载任务失败');
    } finally {
      setFetching(false);
    }
  };

  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      const cleaned = Object.fromEntries(
        Object.entries(values).filter(([, v]) => v !== null && v !== undefined && v !== ''),
      );
      const data: any = {
        ...cleaned,
        deadline: (cleaned.deadline as dayjs.Dayjs)?.toISOString(),
      };

      // Remove audio-specific fields for non-audio types
      if (data.type !== 'audio') {
        delete data.audioFormat;
        delete data.audioChannel;
        delete data.sampleRate;
        delete data.noiseLimit;
        delete data.maxSpeechLength;
        delete data.silencePadding;
        delete data.assistRecognition;
        delete data.silenceDetection;
        delete data.voiceprintDetection;
        delete data.gainDetection;
        delete data.signalDetection;
      }

      // Default status to 'published' if not set
      if (!data.status) {
        data.status = 'in_progress';
      }

      if (isEdit) {
        await taskApi.update(id!, data);
        message.success('更新成功');
      } else {
        await taskApi.create(data);
        message.success('创建成功');
      }
      navigate('/tasks');
    } catch (e: any) {
      const msg = e.response?.data?.message;
      const errorMsg = Array.isArray(msg) ? msg.join('; ') : (msg || (isEdit ? '更新失败' : '创建失败'));
      message.error(errorMsg);
    } finally {
      setLoading(false);
    }
  };


  const handleSaveTexts = async () => {
    const taskId = id;
    const texts = textContent.split('\n').filter((t) => t.trim());
    if (!texts.length) {
      message.warning('请输入文本内容');
      return;
    }
    setSavingText(true);
    try {
      await textCollectionApi.batchCreate({ taskId, texts });
      message.success(`已保存 ${texts.length} 条文本`);
      setTextContent('');
    } catch (e: any) {
      message.error(e.response?.data?.message || '保存失败');
    } finally {
      setSavingText(false);
    }
  };

  if (fetching) return <Spin style={{ display: 'block', margin: '100px auto' }} />;

  return (
    <Row gutter={24}>
      <Col span={taskType === 'text' && isEdit ? 16 : 24}>
    <div>
      <Button
        type="text"
        icon={<ArrowLeftOutlined />}
        onClick={() => navigate('/tasks')}
        style={{ marginBottom: 16 }}
      >
        返回列表
      </Button>
      <Card title={isEdit ? '编辑任务' : '新建任务'}>
        <Form
          form={form}
          layout="vertical"
          onFinish={onFinish}
          initialValues={{
            difficulty: 'easy',
            status: 'in_progress',
            maxClaimsPerUser: 1,
            minQualityScore: 60,
            type: 'audio',
            qcMethod: 'spot_check',
            audioFormat: 'wav',
            audioChannel: 'mono',
            sampleRate: 16000,
            allowMultipleClaims: false,
            reviewRounds: 1,
            recycleHours: 48,
            textAssignCount: 0,
            textCopyForAssign: false,
            assistRecognition: false,
            silenceDetection: false,
            voiceprintDetection: false,
            gainDetection: false,
            signalDetection: false,
          }}
          style={{ maxWidth: 900 }}
        >
          <Tabs
            items={(() => {
              const tabs: any[] = [
                {
                  key: 'basic',
                  label: '基本信息',
                children: (
                  <>
                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="title" label="任务标题" rules={[{ required: true, message: '请输入任务标题' }]}>
                          <Input placeholder="请输入任务标题" />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="type" label="任务类型" rules={[{ required: true }]}>
                          <Select
                            onChange={(v) => setTaskType(v)}
                            options={[
                              { label: '语音', value: 'audio' },
                              { label: '图像', value: 'image' },
                              { label: '视频', value: 'video' },
                              { label: '文本', value: 'text' },
                            ]}
                          />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="projectId" label="所属项目" rules={[{ required: true, message: '请选择项目' }]}>
                          <Select
                            placeholder="选择项目"
                            options={projects.map((p: any) => ({ label: p.name, value: p.id }))}
                          />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Form.Item name="description" label="任务描述">
                      <Input.TextArea rows={3} />
                    </Form.Item>

                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="difficulty" label="难度">
                          <Select
                            options={[
                              { label: '简单', value: 'easy' },
                              { label: '中等', value: 'medium' },
                              { label: '困难', value: 'hard' },
                            ]}
                          />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="unitPrice" label="单价(元)" rules={[{ required: true }]}>
                          <InputNumber min={0.01} step={0.1} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="totalQuantity" label="总数量" rules={[{ required: true }]}>
                          <InputNumber min={1} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="maxClaimsPerUser" label="每人限领">
                          <InputNumber min={1} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="region" label="地域限制">
                          <Input placeholder="如：北京" />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="language" label="语言要求">
                          <Input placeholder="如：普通话" />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Row gutter={16}>
                      <Col span={12}>
                        <Form.Item name="deadline" label="截止时间">
                          <DatePicker showTime style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={12}>
                        <Form.Item name="categoryId" label="分类">
                          <Select
                            allowClear
                            placeholder="选择分类"
                            options={categories.map((c: any) => ({ label: c.name, value: c.id }))}
                          />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Form.Item name="instructions" label="任务说明">
                      <Input.TextArea rows={4} placeholder="详细的任务说明和采集要求" />
                    </Form.Item>

                    <Form.Item name="status" label="状态">
                      <Select
                        options={
                          isEdit
                            ? [
                                { label: '草稿', value: 'draft' },
                                { label: '已发布', value: 'published' },
                                { label: '进行中', value: 'in_progress' },
                                { label: '已完成', value: 'completed' },
                                { label: '已关闭', value: 'closed' },
                              ]
                            : [
                                { label: '进行中', value: 'in_progress' },
                              ]
                        }
                      />
                    </Form.Item>
                  </>
                ),
              },
              {
                key: 'qc',
                label: '质检配置',
                children: (
                  <>
                    <Row gutter={16}>
                      <Col span={12}>
                        <Form.Item name="qcMethod" label="质检方式">
                          <Select
                            options={[
                              { label: '抽检', value: 'spot_check' },
                              { label: '人工抽检', value: 'manual_spot_check' },
                            ]}
                          />
                        </Form.Item>
                      </Col>
                      <Col span={12}>
                        <Form.Item name="minQualityScore" label="最低质量分">
                          <InputNumber min={0} max={100} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                    </Row>
                    <Row gutter={16}>
                      <Col span={12}>
                        <Form.Item name="passRateRequirement" label="合格率要求(%)">
                          <InputNumber min={0} max={100} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={12}>
                        <Form.Item name="reviewRounds" label="验收轮数">
                          <InputNumber min={1} max={10} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                    </Row>
                  </>
                ),
              },
              {
                key: 'assign',
                label: '任务分配',
                children: (
                  <>
                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="allowMultipleClaims" label="允许多次领取" valuePropName="checked">
                          <Switch />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="recycleHours" label="回收时间(小时)">
                          <InputNumber min={1} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="textAssignCount" label="文本分配人数">
                          <InputNumber min={0} style={{ width: '100%' }} placeholder="0=自动" />
                        </Form.Item>
                      </Col>
                    </Row>
                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="textCopyForAssign" label="复制多份分配" valuePropName="checked">
                          <Switch />
                        </Form.Item>
                      </Col>
                    </Row>
                  </>
                ),
              },
            ];

              // Show audio tab + assist tab only for audio type
              if (taskType === 'audio') {
                tabs.push({
                  key: 'audio',
                  label: '音频配置',
                  children: (
                    <>
                      <Row gutter={16}>
                        <Col span={8}>
                          <Form.Item name="audioFormat" label="音频格式">
                            <Select
                              options={[
                                { label: 'WAV', value: 'wav' },
                                { label: 'PCM', value: 'pcm' },
                              ]}
                            />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="audioChannel" label="声道">
                            <Select
                              options={[
                                { label: '单声道', value: 'mono' },
                                { label: '双声道', value: 'stereo' },
                              ]}
                            />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="sampleRate" label="采样率">
                            <Select
                              options={[
                                { label: '16000 Hz', value: 16000 },
                                { label: '44.1 kHz', value: 44100 },
                                { label: '48 kHz', value: 48000 },
                              ]}
                            />
                          </Form.Item>
                        </Col>
                      </Row>
                      <Row gutter={16}>
                        <Col span={8}>
                          <Form.Item name="noiseLimit" label="噪音上限(dB)">
                            <InputNumber min={0} style={{ width: '100%' }} placeholder="如：-30" />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="maxSpeechLength" label="最大语音长度(秒)">
                            <InputNumber min={1} style={{ width: '100%' }} placeholder="如：60" />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="silencePadding" label="静音区预留(ms)">
                            <InputNumber min={0} style={{ width: '100%' }} placeholder="如：300" />
                          </Form.Item>
                        </Col>
                      </Row>
                    </>
                  ),
                });
                tabs.push({
                  key: 'assist',
                  label: '机器辅助',
                  children: (
                    <>
                      <Row gutter={16}>
                        <Col span={8}>
                          <Form.Item name="assistRecognition" label="辅助识别" valuePropName="checked">
                            <Switch />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="silenceDetection" label="静音检测" valuePropName="checked">
                            <Switch />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="voiceprintDetection" label="声纹检测" valuePropName="checked">
                            <Switch />
                          </Form.Item>
                        </Col>
                      </Row>
                      <Row gutter={16}>
                        <Col span={8}>
                          <Form.Item name="gainDetection" label="增幅检测" valuePropName="checked">
                            <Switch />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="signalDetection" label="信号检测" valuePropName="checked">
                            <Switch />
                          </Form.Item>
                        </Col>
                      </Row>
                    </>
                  ),
                });
              }

              return tabs;
            })()}
          />

          <Divider />
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={loading}>
              {isEdit ? '保存修改' : '创建任务'}
            </Button>
            <Button style={{ marginLeft: 8 }} onClick={() => navigate('/tasks')}>
              取消
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
      </Col>
      {taskType === 'text' && isEdit && (
        <Col span={8}>
          <Card title="任务对照内容" size="small">
            <Input.TextArea
              rows={16}
              placeholder="粘贴文本内容，每行一条"
              value={textContent}
              onChange={(e) => setTextContent(e.target.value)}
            />
            <Button
              type="primary"
              loading={savingText}
              style={{ marginTop: 12 }}
              onClick={handleSaveTexts}
            >
              保存文本
            </Button>
          </Card>
        </Col>
      )}
    </Row>
  );
}
