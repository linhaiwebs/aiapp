# XCAI - 数据采集众包平台

数据采集众包平台，支持语音、图像、视频等多类型数据采集任务。

## 架构

```
┌─────────────┐   ┌─────────────┐
│ Flutter App │   │ React Admin │
│  (采集端)    │   │  (管理端)    │
└──────┬──────┘   └──────┬──────┘
       │                 │
       └────────┬────────┘
                │
         ┌──────▼──────┐
         │  NestJS API │
         └──────┬──────┘
       ┌────────┼────────┐
       │        │        │
  ┌────▼──┐ ┌──▼───┐ ┌──▼───┐
  │  PG   │ │Redis │ │MinIO │
  └───────┘ └──────┘ └──────┘
```

## 项目结构

```
aiapp/
├── server/          # NestJS 后端
├── admin/           # React 管理后台
├── app/             # Flutter 移动端
├── deploy/          # 部署配置
└── docs/            # 文档
```

## 快速开始

### 后端 (NestJS)

```bash
cd server
cp .env.example .env
npm install
npm run start:dev
```

### 管理后台 (React)

```bash
cd admin
npm install
npm run dev
```

### 移动端 (Flutter)

```bash
cd app
flutter pub get
flutter run
```

### Docker 部署

```bash
cd deploy
docker-compose up -d
```

## 核心流程

1. **注册登录** → 手机号+验证码 / 微信 / QQ
2. **实名认证** → 身份证验证
3. **领取任务** → 浏览任务广场，选择任务
4. **数据采集** → 语音/图像/视频录制
5. **实时质检** → 采集后自动QC
6. **提交审核** → 人工审核确认
7. **结算收益** → 审核通过后结算

## 技术栈

| 组件 | 技术 |
|------|------|
| 后端 | NestJS + TypeORM + PostgreSQL + Redis + MinIO |
| 管理端 | React + TypeScript + Ant Design + Vite |
| 移动端 | Flutter + Riverpod + Go Router |
| 部署 | Docker Compose + Nginx |
