import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Descriptions, Spin, Tag, Button, Progress, message } from 'antd';
import { EditOutlined, ArrowLeftOutlined } from '@ant-design/icons';
import { taskApi } from '../../api';

const typeColors: Record<string, string> = {
  audio: 'blue',
  image: 'green',
  video: 'orange',
};

const typeLabels: Record<string, string> = {
  audio: '语音',
  image: '图像',
  video: '视频',
};

const statusMap: Record<string, { label: string; color: string }> = {
  draft: { label: '草稿', color: 'default' },
  published: { label: '已发布', color: 'blue' },
  in_progress: { label: '进行中', color: 'green' },
  completed: { label: '已完成', color: 'cyan' },
  closed: { label: '已关闭', color: 'red' },
};

export default function TaskDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [task, setTask] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadTask();
  }, [id]);

  const loadTask = async () => {
    try {
      const res: any = await taskApi.detail(id!);
      setTask(res);
    } catch {
      message.error('加载任务失败');
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <Spin />;
  if (!task) return <div>任务不存在</div>;

  const completionRate = task.totalQuantity > 0
    ? Math.round((task.completedQuantity / task.totalQuantity) * 100)
    : 0;
  const claimRate = task.totalQuantity > 0
    ? Math.round((task.claimedQuantity / task.totalQuantity) * 100)
    : 0;

  return (
    <div>
      <Button
        type="text"
        icon={<ArrowLeftOutlined />}
        onClick={() => navigate('/tasks')}
        style={{ marginBottom: 16 }}
      >
        返回列表
      </Button>
      <Card
        title={task.title}
        extra={
          <Button
            type="primary"
            icon={<EditOutlined />}
            onClick={() => navigate(`/tasks/${id}/edit`)}
          >
            编辑
          </Button>
        }
      >
        <Descriptions bordered column={2} size="small">
          <Descriptions.Item label="任务标题">{task.title}</Descriptions.Item>
          <Descriptions.Item label="类型">
            <Tag color={typeColors[task.type]}>{typeLabels[task.type] || task.type}</Tag>
          </Descriptions.Item>
          <Descriptions.Item label="状态">
            <Tag color={statusMap[task.status]?.color}>{statusMap[task.status]?.label || task.status}</Tag>
          </Descriptions.Item>
          <Descriptions.Item label="难度">
            <Tag>{task.difficulty === 'easy' ? '简单' : task.difficulty === 'medium' ? '中等' : '困难'}</Tag>
          </Descriptions.Item>
          <Descriptions.Item label="单价">¥{task.unitPrice}</Descriptions.Item>
          <Descriptions.Item label="总数量">{task.totalQuantity}</Descriptions.Item>
          <Descriptions.Item label="已领取">{task.claimedQuantity}</Descriptions.Item>
          <Descriptions.Item label="已完成">{task.completedQuantity}</Descriptions.Item>
          <Descriptions.Item label="每人限领">{task.maxClaimsPerUser || '-'}</Descriptions.Item>
          <Descriptions.Item label="地域">{task.region || '不限'}</Descriptions.Item>
          <Descriptions.Item label="语言">{task.language || '不限'}</Descriptions.Item>
          <Descriptions.Item label="最低质量分">{task.minQualityScore ?? '-'}</Descriptions.Item>
          <Descriptions.Item label="合格率要求">{task.passRateRequirement ? `${task.passRateRequirement}%` : '-'}</Descriptions.Item>
          <Descriptions.Item label="截止时间">
            {task.deadline ? new Date(task.deadline).toLocaleString() : '不限'}
          </Descriptions.Item>
          <Descriptions.Item label="描述" span={2}>
            {task.description || '-'}
          </Descriptions.Item>
          <Descriptions.Item label="任务说明" span={2}>
            <div style={{ whiteSpace: 'pre-wrap' }}>{task.instructions || '-'}</div>
          </Descriptions.Item>
          {task.project && (
            <Descriptions.Item label="所属项目" span={2}>
              <a onClick={() => navigate(`/projects/${task.project.id}`)}>{task.project.name}</a>
            </Descriptions.Item>
          )}
          {task.category && (
            <Descriptions.Item label="分类" span={2}>
              {task.category.name}
            </Descriptions.Item>
          )}
          <Descriptions.Item label="创建时间">
            {task.createdAt ? new Date(task.createdAt).toLocaleString() : '-'}
          </Descriptions.Item>
          <Descriptions.Item label="更新时间">
            {task.updatedAt ? new Date(task.updatedAt).toLocaleString() : '-'}
          </Descriptions.Item>
        </Descriptions>

        <div style={{ marginTop: 24 }}>
          <h4>进度</h4>
          <div style={{ marginBottom: 12 }}>
            <span style={{ marginRight: 16 }}>领取率:</span>
            <Progress percent={claimRate} style={{ display: 'inline-block', width: 300 }} />
            <span style={{ marginLeft: 8 }}>{task.claimedQuantity}/{task.totalQuantity}</span>
          </div>
          <div>
            <span style={{ marginRight: 16 }}>完成率:</span>
            <Progress percent={completionRate} style={{ display: 'inline-block', width: 300 }} strokeColor="#52c41a" />
            <span style={{ marginLeft: 8 }}>{task.completedQuantity}/{task.totalQuantity}</span>
          </div>
        </div>
      </Card>
    </div>
  );
}
