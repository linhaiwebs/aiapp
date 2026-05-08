import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Form, Input, Button, Card, message, Typography, Tabs } from 'antd';
import { UserOutlined, LockOutlined, MobileOutlined } from '@ant-design/icons';
import { authApi } from '../../api';
import { useAuthStore } from '../../stores/auth';

const { Title, Text } = Typography;

export default function Login() {
  const [loading, setLoading] = useState(false);
  const [loginMode, setLoginMode] = useState<'password' | 'sms'>('password');
  const [smsSending, setSmsSending] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const navigate = useNavigate();
  const { login } = useAuthStore();
  const [passwordForm] = Form.useForm();
  const [smsForm] = Form.useForm();

  useEffect(() => {
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, []);

  useEffect(() => {
    if (countdown > 0) {
      timerRef.current = setInterval(() => setCountdown(c => c - 1), 1000);
    } else if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, [countdown]);

  const onPasswordLogin = async (values: { phone: string; password: string }) => {
    setLoading(true);
    try {
      const res: any = await authApi.login(values);
      handleLoginSuccess(res);
    } catch (err: any) {
      message.error(err.response?.data?.message || '手机号或密码错误');
    } finally {
      setLoading(false);
    }
  };

  const onSmsLogin = async (values: { phone: string; smsCode: string }) => {
    setLoading(true);
    try {
      const res: any = await authApi.smsLogin(values);
      handleLoginSuccess(res);
    } catch (err: any) {
      message.error(err.response?.data?.message || '验证码错误');
    } finally {
      setLoading(false);
    }
  };

  const handleLoginSuccess = (res: any) => {
    const accessToken = res.accessToken;
    const refreshToken = res.refreshToken;
    const user = res.user;
    if (!accessToken) {
      message.error('登录返回数据异常');
      return;
    }
    login(accessToken, refreshToken, user);
    message.success('登录成功');
    navigate('/dashboard', { replace: true });
  };

  const sendSmsCode = async () => {
    const phone = smsForm.getFieldValue('phone');
    if (!phone || phone.length < 11) {
      message.warning('请输入正确的手机号');
      return;
    }
    setSmsSending(true);
    try {
      await authApi.sendSms({ phone });
      message.success('验证码已发送');
      setCountdown(60);
    } catch (err: any) {
      message.error(err.response?.data?.message || '发送失败');
    } finally {
      setSmsSending(false);
    }
  };

  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      }}
    >
      <Card
        style={{
          width: 420,
          borderRadius: 12,
          boxShadow: '0 8px 40px rgba(0,0,0,0.12)',
        }}
        styles={{ body: { padding: '40px 32px' } }}
      >
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <Title level={3} style={{ marginBottom: 4 }}>XCAI 管理后台</Title>
          <Text type="secondary">数据采集众包平台</Text>
        </div>

        <Tabs
          activeKey={loginMode}
          onChange={(key) => setLoginMode(key as 'password' | 'sms')}
          centered
          items={[
            { key: 'password', label: '密码登录' },
            { key: 'sms', label: '验证码登录' },
          ]}
        />

        {loginMode === 'password' ? (
          <Form form={passwordForm} onFinish={onPasswordLogin} size="large">
            <Form.Item name="phone" rules={[{ required: true, message: '请输入手机号' }]}>
              <Input prefix={<UserOutlined />} placeholder="手机号" />
            </Form.Item>
            <Form.Item name="password" rules={[{ required: true, message: '请输入密码' }]}>
              <Input.Password prefix={<LockOutlined />} placeholder="密码" />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" loading={loading} block>
                登录
              </Button>
            </Form.Item>
          </Form>
        ) : (
          <Form form={smsForm} onFinish={onSmsLogin} size="large">
            <Form.Item name="phone" rules={[{ required: true, message: '请输入手机号' }]}>
              <Input prefix={<MobileOutlined />} placeholder="手机号" />
            </Form.Item>
            <Form.Item name="smsCode" rules={[{ required: true, message: '请输入验证码' }]}>
              <Input
                placeholder="验证码"
                maxLength={6}
                addonAfter={
                  <Button
                    type="link"
                    size="small"
                    disabled={countdown > 0 || smsSending}
                    onClick={sendSmsCode}
                    loading={smsSending}
                    style={{ padding: 0, height: 'auto' }}
                  >
                    {countdown > 0 ? `${countdown}s` : '获取验证码'}
                  </Button>
                }
              />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" loading={loading} block>
                登录
              </Button>
            </Form.Item>
          </Form>
        )}

        <div style={{ textAlign: 'center' }}>
          <Text type="secondary" style={{ fontSize: 12 }}>
            端云智采 ©{new Date().getFullYear()}
          </Text>
        </div>
      </Card>
    </div>
  );
}
