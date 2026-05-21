import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Form, Input, Select, InputNumber, DatePicker, Button, Spin, message, Row, Col, Switch, Divider, Tabs } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { taskApi, projectApi, categoryApi, textCollectionApi, projectDocumentApi } from '../../api';

export default function TaskForm() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(!!id);
  const [projects, setProjects] = useState<any[]>([]);
  const [categories, setCategories] = useState<any[]>([]);
  const [textContent, setTextContent] = useState('');
  const [savingText, setSavingText] = useState(false);
  const [projectDocs, setProjectDocs] = useState<any[]>([]);
  const [loadingDoc, setLoadingDoc] = useState(false);
  const isEdit = !!id;

  // 多人分配相关
  const assignMode: string = Form.useWatch('textAssignMode', form) || 'auto';
  const docLineCount: number = Form.useWatch('_docLineCount', form) || 0;
  const assignPeople: number = Form.useWatch('textAssignCount', form) || 0;
  const evenPreview = assignPeople > 0 ? Math.ceil(docLineCount / assignPeople) : 0;

  useEffect(() => {
    if (assignMode !== 'even') form.setFieldsValue({ textAssignCount: undefined });
    if (assignMode !== 'per_user') form.setFieldsValue({ textPerUserCount: undefined });
  }, [assignMode, form]);

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

  const loadProjectDocs = async (projectId: string) => {
    if (!projectId) {
      setProjectDocs([]);
      return;
    }
    try {
      const res: any = await projectDocumentApi.list(projectId);
      setProjectDocs(Array.isArray(res) ? res : []);
    } catch {
      setProjectDocs([]);
    }
  };

  const handleSelectDoc = async (docId: string) => {
    if (!docId) return;
    const projectId = form.getFieldValue('projectId');
    if (!projectId) return;
    setLoadingDoc(true);
    try {
      const res: any = await projectDocumentApi.detail(projectId, docId);
      if (res?.content) {
        form.setFieldsValue({ instructions: res.content });
        // 计算文本行数（非空行）
        const lines = res.content.split('\n').filter((l: string) => l.trim());
        form.setFieldsValue({ _docLineCount: lines.length });
        message.info(`文档共 ${lines.length} 行文本，将自动作为任务总数量`);
      }
    } catch {
      message.error('加载文档内容失败');
    } finally {
      setLoadingDoc(false);
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
        _docLineCount: res.totalQuantity || 0,
      });
    } catch {
      message.error('加载任务失败');
    } finally {
      setFetching(false);
    }
  };

  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      // 从文档行数计算 totalQuantity
      if (values._docLineCount && !values.totalQuantity) {
        values.totalQuantity = values._docLineCount;
      }
      const cleaned = Object.fromEntries(
        Object.entries(values).filter(([, v]) => v !== null && v !== undefined && v !== ''),
      );
      // Remove the fake form field (not a real DB column)
      delete cleaned._docLineCount;
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
        delete data.silenceDetection;
        delete data.gainDetection;
        delete data.signalDetection;
      }

      // Default status to 'published' if not set
      if (!data.status) {
        data.status = 'in_progress';
      }

      let savedTask: any;
      if (isEdit) {
        savedTask = await taskApi.update(id!, data);
        message.success('更新成功');
        // 更新已有任务的文本：删除旧的，重新创建
        const lines = (data.instructions || '').split('\n').filter((l: string) => l.trim());
        if (lines.length > 0) {
          try {
            await textCollectionApi.batchCreate({ taskId: id!, texts: lines });
            message.success(`已同步 ${lines.length} 条文本`);
          } catch { /* 非阻塞 */ }
        }
      } else {
        savedTask = await taskApi.create(data);
        message.success('创建成功');
        // 自动从任务说明创建文本采集条目
        const lines = (data.instructions || '').split('\n').filter((l: string) => l.trim());
        if (lines.length > 0) {
          try {
            await textCollectionApi.batchCreate({ taskId: savedTask.id, texts: lines });
            message.success(`已自动创建 ${lines.length} 条文本`);
          } catch { /* 非阻塞 */ }
        }
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
    if (!id) {
      message.warning('请先创建任务后再保存文本');
      return;
    }
    const texts = textContent.split('\n').filter((t) => t.trim());
    if (!texts.length) {
      message.warning('请输入文本内容');
      return;
    }
    setSavingText(true);
    try {
      await textCollectionApi.batchCreate({ taskId: id, texts });
      message.success(`已保存 ${texts.length} 条文本`);
      setTextContent('');
    } catch (e: any) {
      message.error(e.response?.data?.message || '保存失败');
    } finally {
      setSavingText(false);
    }
  };

  // ── 这些 hooks 必须在 early return 之前，保证每次渲染调用次数一致 ──
  const watchedProjectId = Form.useWatch('projectId', form);
  const watchedType = Form.useWatch('type', form);
  const taskType: string = watchedType || 'audio';

  useEffect(() => {
    loadProjectDocs(watchedProjectId);
    // 自动从项目继承任务类型
    if (watchedProjectId) {
      const project = projects.find((p: any) => p.id === watchedProjectId);
      if (project?.type) {
        form.setFieldsValue({ type: project.type });
      }
    }
  }, [watchedProjectId, projects]);

  if (fetching) return <Spin style={{ display: 'block', margin: '100px auto' }} />;

  return (
    <Row gutter={24}>
      <Col span={taskType === 'text' ? 16 : 24}>
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
            qcMethod: 'spot_check',
            audioFormat: 'opus',
            audioChannel: 'mono',
            sampleRate: 16000,
            allowMultipleClaims: false,
            reviewRounds: 1,
            recycleHours: 48,
            textAssignMode: 'auto',
            textAssignCount: 0,
            textPerUserCount: 0,
            textCopyForAssign: false,
            silenceDetection: false,
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
                        <Form.Item name="title" label="任务标题" tooltip="任务的名称，采集员可见" rules={[{ required: true, message: '请输入任务标题' }]}>
                          <Input placeholder="请输入任务标题" />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="type" label="任务类型" tooltip="由所属项目决定，不可手动更改">
                          <Select disabled options={[
                            { label: '语音', value: 'audio' },
                            { label: '图像', value: 'image' },
                            { label: '视频', value: 'video' },
                            { label: '文本', value: 'text' },
                          ]} />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="projectId" label="所属项目" tooltip="任务归属的项目" rules={[{ required: true, message: '请选择项目' }]}>
                          <Select
                            placeholder="选择项目"
                            options={projects.map((p: any) => ({ label: p.name, value: p.id }))}
                          />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Form.Item name="description" label="任务描述" tooltip="对任务内容和要求的简要描述">
                      <Input.TextArea rows={3} />
                    </Form.Item>

                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="difficulty" label="难度" tooltip="任务难度等级：简单、中等、困难">
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
                        <Form.Item name="unitPrice" label="单价(元)" tooltip="每完成一个任务单位支付给采集员的费用" rules={[{ required: true }]}>
                          <InputNumber min={0.01} step={0.1} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="_docLineCount" label="文本行数" tooltip="从项目文档自动计算的行数，或手动输入">
                          <InputNumber min={1} style={{ width: '100%' }} disabled placeholder="选择文档后自动填充" />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="maxClaimsPerUser" label="可领取次数" tooltip="每个采集员最多可领取该任务的次数（每次领取获得一批文本）">
                          <InputNumber min={1} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="region" label="地域限制" tooltip="限制可参与任务的采集员地理区域">
                          <Input placeholder="如：北京" />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="language" label="语言要求" tooltip="采集员需具备的语言能力要求，如：普通话">
                          <Input placeholder="如：普通话" />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Row gutter={16}>
                      <Col span={12}>
                        <Form.Item name="deadline" label="截止时间" tooltip="任务关闭申请的截止日期时间">
                          <DatePicker showTime style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={12}>
                        <Form.Item name="categoryId" label="分类" tooltip="任务所属的分类标签">
                          <Select
                            allowClear
                            placeholder="选择分类"
                            options={categories.map((c: any) => ({ label: c.name, value: c.id }))}
                          />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Row gutter={16}>
                      <Col span={12}>
                        <Form.Item label="从项目文档填充" tooltip="选择项目下已上传的文本，内容将自动填充到任务说明">
                          <Select
                            allowClear
                            loading={loadingDoc}
                            placeholder="选择文档（可选）"
                            options={projectDocs.map((d: any) => ({ label: d.title, value: d.id }))}
                            onChange={handleSelectDoc}
                            notFoundContent={!watchedProjectId ? '请先选择项目' : '该项目暂无上传的文档'}
                          />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Form.Item name="instructions" label="任务说明" tooltip="详细的任务说明和采集操作要求">
                      <Input.TextArea rows={4} placeholder="详细的任务说明和采集要求" />
                    </Form.Item>

                    <Form.Item name="status" label="状态" tooltip="任务当前的生命周期状态">
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
                        <Form.Item name="qcMethod" label="质检方式" tooltip="抽检=系统自动抽查，人工抽检=人工抽查">
                          <Select
                            options={[
                              { label: '抽检', value: 'spot_check' },
                              { label: '人工抽检', value: 'manual_spot_check' },
                            ]}
                          />
                        </Form.Item>
                      </Col>
                      <Col span={12}>
                        <Form.Item name="minQualityScore" label="最低质量分" tooltip="采集结果合格的最低质量分数，低于此分将被驳回">
                          <InputNumber min={0} max={100} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                    </Row>
                    <Row gutter={16}>
                      <Col span={12}>
                        <Form.Item name="passRateRequirement" label="合格率要求(%)" tooltip="采集员提交的合格率百分比要求">
                          <InputNumber min={0} max={100} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                      <Col span={12}>
                        <Form.Item name="reviewRounds" label="验收轮数" tooltip="提交结果需要经过几轮验收审核">
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
                        <Form.Item name="allowMultipleClaims" label="允许多次领取" valuePropName="checked" tooltip="开启后允许采集员多次领取，配合「可领取次数」控制上限">
                          <Switch />
                        </Form.Item>
                      </Col>
                      <Col span={8}>
                        <Form.Item name="recycleHours" label="回收时间(小时)" tooltip="任务领取后超时未完成将自动回收">
                          <InputNumber min={1} style={{ width: '100%' }} />
                        </Form.Item>
                      </Col>
                    </Row>

                    <Divider orientation="left" orientationMargin={0}>多人分配</Divider>

                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="textAssignMode" label="分配模式" tooltip="auto=每人全量（可多次领取）| even=按顺序均分 | per_user=每人固定条数">
                          <Select
                            options={[
                              { label: '自动分配（每人全量）', value: 'auto' },
                              { label: '平均分配（按领取顺序）', value: 'even' },
                              { label: '每人指定数量', value: 'per_user' },
                            ]}
                          />
                        </Form.Item>
                      </Col>

                      {assignMode === 'even' && (
                        <>
                          <Col span={6}>
                            <Form.Item name="textAssignCount" label="分配人数" tooltip="文档行数÷人数=每人条数，按领取顺序分配" rules={[{ required: true, message: '请输入分配人数' }]}>
                              <InputNumber min={1} style={{ width: '100%' }} placeholder="如：100" />
                            </Form.Item>
                          </Col>
                          <Col span={6}>
                            <Form.Item label="预计每人">
                              <InputNumber
                                disabled
                                value={evenPreview}
                                style={{ width: '100%', color: evenPreview > 0 ? '#1677ff' : '#999' }}
                                prefix={evenPreview > 0 ? '≈' : undefined}
                                suffix="条"
                              />
                            </Form.Item>
                          </Col>
                        </>
                      )}

                      {assignMode === 'per_user' && (
                        <Col span={6}>
                          <Form.Item name="textPerUserCount" label="每人条数" tooltip="每位采集员固定分配X条文本" rules={[{ required: true, message: '请输入每人条数' }]}>
                            <InputNumber min={1} style={{ width: '100%' }} placeholder="如：100" />
                          </Form.Item>
                        </Col>
                      )}
                    </Row>

                    <Row gutter={16}>
                      <Col span={8}>
                        <Form.Item name="textCopyForAssign" label="复制多份分配" valuePropName="checked" tooltip="开启后将文本复制多份分配给不同采集员（同一文本多人采集）">
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
                          <Form.Item name="audioFormat" label="音频格式" tooltip="Opus 推荐（体积小音质好）| WAV 无损 | PCM 原始">
                            <Select
                              options={[
                                { label: 'WAV', value: 'wav' },
                                { label: 'PCM', value: 'pcm' },
                                { label: 'Opus', value: 'opus' },
                              ]}
                            />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="audioChannel" label="声道" tooltip="声道数量：单声道或双声道">
                            <Select
                              options={[
                                { label: '单声道', value: 'mono' },
                                { label: '双声道', value: 'stereo' },
                              ]}
                            />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="sampleRate" label="采样率" tooltip="音频采样率，越高音质越好文件越大">
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
                          <Form.Item name="noiseLimit" label="噪音上限(dB)" tooltip="允许的最大环境噪音分贝值">
                            <InputNumber min={0} style={{ width: '100%' }} placeholder="如：-30" />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="maxSpeechLength" label="最大语音长度(秒)" tooltip="单条音频的最大时长限制">
                            <InputNumber min={1} style={{ width: '100%' }} placeholder="如：60" />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="silencePadding" label="静音区预留(ms)" tooltip="音频首尾静音区域的预留时长">
                            <InputNumber min={0} style={{ width: '100%' }} placeholder="如：300" />
                          </Form.Item>
                        </Col>
                      </Row>
                    </>
                  ),
                });
                tabs.push({
                  key: 'assist',
                  label: '音频检测',
                  children: (
                    <>
                      <Row gutter={16}>
                        <Col span={8}>
                          <Form.Item name="silenceDetection" label="静音检测" valuePropName="checked" tooltip="录音前检测环境噪音是否超标">
                            <Switch />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="gainDetection" label="增幅检测" valuePropName="checked" tooltip="录音前检测信号增益是否正常">
                            <Switch />
                          </Form.Item>
                        </Col>
                        <Col span={8}>
                          <Form.Item name="signalDetection" label="信号检测" valuePropName="checked" tooltip="录音前检测是否有有效音频信号">
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
      {taskType === 'text' && (
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
