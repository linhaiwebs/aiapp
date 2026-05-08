import { useState } from 'react';
import { Card, Button, Space, Select, Radio, message, Input, Modal } from 'antd';
import { DownloadOutlined, FileTextOutlined, SoundOutlined, CodeOutlined, CopyOutlined } from '@ant-design/icons';
import { exportApi, taskApi, projectApi } from '../../api';

export default function DataExport() {
  const [projectId, setProjectId] = useState<string | undefined>();
  const [taskId, setTaskId] = useState<string | undefined>();
  const [format, setFormat] = useState<string>('json');
  const [projects, setProjects] = useState<any[]>([]);
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [scriptModal, setScriptModal] = useState(false);
  const [scriptContent, setScriptContent] = useState('');

  const loadProjects = async () => {
    try {
      const res: any = await projectApi.list({ pageSize: 100 });
      setProjects(res.items || []);
    } catch { /* ignore */ }
  };

  const loadTasks = async () => {
    try {
      const res: any = await taskApi.list({ pageSize: 100 });
      setTasks(res.items || []);
    } catch { /* ignore */ }
  };

  useState(() => { loadProjects(); loadTasks(); });

  const handleExportTasks = async () => {
    setLoading(true);
    try {
      const res: any = await exportApi.tasks({ projectId, format });
      if (format === 'json') {
        downloadFile(JSON.stringify(res, null, 2), `tasks.${format}`, format === 'json' ? 'application/json' : 'text/csv');
      } else {
        downloadFile(res, `tasks.csv`, 'text/csv');
      }
      message.success('导出成功');
    } catch (e: any) {
      message.error('导出失败: ' + (e.message || '未知错误'));
    } finally { setLoading(false); }
  };

  const handleExportSubmissions = async () => {
    setLoading(true);
    try {
      const res: any = await exportApi.submissions({ taskId, format });
      if (format === 'json') {
        downloadFile(JSON.stringify(res, null, 2), `submissions.${format}`, 'application/json');
      } else {
        downloadFile(res, `submissions.csv`, 'text/csv');
      }
      message.success('导出成功');
    } catch (e: any) {
      message.error('导出失败: ' + (e.message || '未知错误'));
    } finally { setLoading(false); }
  };

  const handleExportAudioLinks = async () => {
    setLoading(true);
    try {
      const res: any = await exportApi.audioLinks({ taskId });
      downloadFile(JSON.stringify(res, null, 2), 'audio_links.json', 'application/json');
      message.success('导出成功');
    } catch (e: any) {
      message.error('导出失败: ' + (e.message || '未知错误'));
    } finally { setLoading(false); }
  };

  const generateExportScript = () => {
    const apiBase = window.location.origin;
    const script = `#!/bin/bash
# XCAI 数据导出脚本
# 使用方法: bash export_script.sh [TASK_ID]
# 环境变量: TOKEN=your_jwt_token

API_BASE="${apiBase}/api"
TOKEN=\${TOKEN:-""}
TASK_ID=\${1:-""}

if [ -z "$TOKEN" ]; then
  echo "请设置 TOKEN 环境变量"
  echo "用法: TOKEN=xxx bash export_script.sh [TASK_ID]"
  exit 1
fi

AUTH="Authorization: Bearer $TOKEN"
OUTDIR="xcai_export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

echo "📂 导出目录: $OUTDIR"

# 导出任务信息
echo "📋 导出任务信息..."
curl -s -H "$AUTH" "$API_BASE/admin/export/tasks?format=json" \\
  -o "$OUTDIR/tasks.json"

# 导出采集信息
echo "📊 导出采集信息..."
curl -s -H "$AUTH" "$API_BASE/admin/export/submissions?taskId=$TASK_ID&format=json" \\
  -o "$OUTDIR/submissions.json"

# 导出音频链接
echo "🔊 导出音频链接..."
curl -s -H "$AUTH" "$API_BASE/admin/export/audio-links?taskId=$TASK_ID" \\
  -o "$OUTDIR/audio_links.json"

# 下载音频文件
echo "⬇️  下载音频文件..."
mkdir -p "$OUTDIR/audio"
if [ -f "$OUTDIR/audio_links.json" ]; then
  cat "$OUTDIR/audio_links.json" | python3 -c "
import json, sys, urllib.request
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('items', [])
for item in items:
    url = item.get('url') or item.get('downloadUrl', '')
    fid = item.get('fileId', item.get('id', 'unknown'))
    if url:
        print(f'  下载: {fid}')
        try:
            urllib.request.urlretrieve(url, f'$OUTDIR/audio/{fid}.wav')
        except Exception as e:
            print(f'  失败: {e}')
"
fi

echo "✅ 导出完成！文件保存在: $OUTDIR"
ls -la "$OUTDIR"
`;
    setScriptContent(script);
    setScriptModal(true);
  };

  const downloadFile = (content: any, filename: string, mimeType: string) => {
    const blob = content instanceof Blob ? content : new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <Card title="数据导出">
      <Space direction="vertical" size="large" style={{ width: '100%' }}>
        <div>
          <Space style={{ marginBottom: 16 }}>
            <span>导出格式：</span>
            <Radio.Group value={format} onChange={e => setFormat(e.target.value)}>
              <Radio.Button value="json">JSON</Radio.Button>
              <Radio.Button value="csv">CSV/表格</Radio.Button>
            </Radio.Group>
          </Space>
        </div>

        <Card type="inner" title={<Space><FileTextOutlined />任务信息导出</Space>}>
          <Space wrap>
            <Select allowClear placeholder="按项目筛选" style={{ width: 200 }} value={projectId}
              onChange={setProjectId} options={projects.map((p: any) => ({ label: p.name, value: p.id }))} />
            <Button type="primary" icon={<DownloadOutlined />} onClick={handleExportTasks} loading={loading}>
              导出任务信息
            </Button>
          </Space>
        </Card>

        <Card type="inner" title={<Space><FileTextOutlined />个人采集信息导出</Space>}>
          <Space wrap>
            <Select allowClear placeholder="按任务筛选" style={{ width: 200 }} value={taskId}
              onChange={setTaskId} options={tasks.map((t: any) => ({ label: t.title, value: t.id }))} />
            <Button type="primary" icon={<DownloadOutlined />} onClick={handleExportSubmissions} loading={loading}>
              导出采集信息
            </Button>
          </Space>
        </Card>

        <Card type="inner" title={<Space><SoundOutlined />音频文件链接导出</Space>}>
          <Space wrap>
            <Select allowClear placeholder="按任务筛选" style={{ width: 200 }} value={taskId}
              onChange={setTaskId} options={tasks.map((t: any) => ({ label: t.title, value: t.id }))} />
            <Button type="primary" icon={<DownloadOutlined />} onClick={handleExportAudioLinks} loading={loading}>
              导出音频链接
            </Button>
            <div style={{ color: '#999', fontSize: 12 }}>导出JSON格式的音频文件链接列表，可直接在线播放</div>
          </Space>
        </Card>

        <Card type="inner" title={<Space><CodeOutlined />脚本导出</Space>}>
          <Space direction="vertical" style={{ width: '100%' }}>
            <div>生成线下导出脚本，可在服务器端批量导出音频文件及数据</div>
            <Button icon={<CodeOutlined />} onClick={generateExportScript}>生成导出脚本</Button>
          </Space>
        </Card>
      </Space>

      <Modal title="导出脚本" open={scriptModal} onCancel={() => setScriptModal(false)} width={700}
        footer={[
          <Button key="copy" icon={<CopyOutlined />} onClick={() => { navigator.clipboard.writeText(scriptContent); message.success('已复制到剪贴板'); }}>复制</Button>,
          <Button key="download" type="primary" icon={<DownloadOutlined />} onClick={() => downloadFile(scriptContent, 'export_script.sh', 'text/x-shellscript')}>下载脚本</Button>,
          <Button key="close" onClick={() => setScriptModal(false)}>关闭</Button>,
        ]}>
        <Input.TextArea rows={20} value={scriptContent} readOnly style={{ fontFamily: 'monospace', fontSize: 12 }} />
      </Modal>
    </Card>
  );
}
