# XCAI 端云智采 — 功能介绍与测试文档

---

## 一、系统概述

XCAI 端云智采是一个数据采集众包平台，用于管理语音、文本、图像等数据的采集、质检和导出流程。系统由三部分组成：

| 组件 | 技术栈 | 说明 |
|------|--------|------|
| 后端服务 (Server) | NestJS + TypeORM + PostgreSQL/SQLite | API 服务，数据处理，文件存储 |
| 管理后台 (Admin) | React + Ant Design + Vite | 项目管理、任务配置、数据质检、账号管理 |
| 采集 APP | Flutter + Riverpod | 采集员领取任务、录音上传、数据提交 |

### 用户角色

| 角色 | 权限 | 主要操作 |
|------|------|---------|
| 超级管理员 (super_admin) | 全部权限 | 项目管理、账号管理、系统配置、数据导出 |
| 管理员 (admin) | 管理权限 | 项目管理、任务管理、质检审核 |
| 审核员 (reviewer) | 质检权限 | 质检审核、数据标记、通过/驳回 |
| 采集员 (collector) | 采集权限 | 领取任务、录音采集、提交数据 |

### 默认账号

| 角色 | 手机号 | 密码 |
|------|--------|------|
| 超级管理员 | 13800000000 | admin123 |
| 审核员 | 13800000001 | reviewer123 |

---

## 二、功能模块详解

### 模块 1：认证与账号 (Auth / User)

#### 1.1 功能说明

- 手机号 + 密码登录
- 短信验证码登录
- JWT Token 认证（Access Token + Refresh Token）
- 第三方登录预留接口（微信/QQ）
- 用户注册
- 实名认证
- 用户状态管理（启用/禁用/拉黑）

#### 1.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/auth/register` | 用户注册 | 公开 |
| POST | `/api/auth/login` | 手机号+密码登录 | 公开 |
| POST | `/api/auth/sms/login` | 短信验证码登录 | 公开 |
| POST | `/api/auth/sms/send` | 发送验证码 | 公开 |
| POST | `/api/auth/refresh` | 刷新 Token | 登录 |
| POST | `/api/auth/real-name` | 实名认证 | 登录 |
| GET | `/api/auth/me` | 获取当前用户信息 | 登录 |
| GET | `/api/users` | 用户列表 | admin+ |
| GET | `/api/users/:id` | 用户详情 | admin+ |
| POST | `/api/users` | 创建用户 | admin+ |
| POST | `/api/users/invite` | 邀请新成员 | admin+ |
| PATCH | `/api/users/:id` | 更新用户 | admin+ |
| PATCH | `/api/users/:id/status` | 更新用户状态 | admin+ |

#### 1.3 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| AUTH-001 | 管理员登录 | POST `/api/auth/login` body: `{phone: "13800000000", password: "admin123"}` | 返回 200，包含 accessToken 和 refreshToken |
| AUTH-002 | 错误密码登录 | POST `/api/auth/login` body: `{phone: "13800000000", password: "wrong"}` | 返回 401 Unauthorized |
| AUTH-003 | 不存在的手机号 | POST `/api/auth/login` body: `{phone: "19999999999", password: "xxx"}` | 返回 401 |
| AUTH-004 | Token 刷新 | POST `/api/auth/refresh` body: `{refreshToken: "xxx"}` | 返回新的 accessToken |
| AUTH-005 | 无效 Token 访问 | GET `/api/auth/me` header 无 Authorization | 返回 401 |
| AUTH-006 | 获取当前用户 | GET `/api/auth/me` 带有效 Token | 返回用户信息，含 phone/nickname/role |
| AUTH-007 | 用户注册 | POST `/api/auth/register` 合法数据 | 返回 201，创建成功 |
| AUTH-008 | 重复注册 | POST `/api/auth/register` 同一手机号 | 返回 409 Conflict |
| AUTH-009 | 创建用户（管理员） | POST `/api/users` 带管理员 Token | 创建成功 |
| AUTH-010 | 修改用户状态 | PATCH `/api/users/:id/status` 设为 inactive | 用户状态更新 |

---

### 模块 2：项目管理 (Project)

#### 2.1 功能说明

项目是采集任务的顶层容器，定义了项目级别的配置：

- 项目名称、描述、起止日期
- **项目地区**：设定采集区域
- **部门识别方式**：标识项目归属部门
- **领取方式**：单次领取（每人只能领一次）/ 多次领取（可重复领取）
- **负责人**：项目管理人
- **验收人**：负责审核最终数据的人
- **授权签名**：采集前是否需要授权签名确认
- **回收时间**：超时未完成任务自动回收（默认 48 小时）
- 质检规则配置
- 报酬模板

#### 2.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/projects` | 项目列表 | 登录 |
| GET | `/api/projects/:id` | 项目详情 | 登录 |
| POST | `/api/projects` | 创建项目 | admin+ |
| PATCH | `/api/projects/:id` | 更新项目 | admin+ |
| DELETE | `/api/projects/:id` | 删除项目 | super_admin |

#### 2.3 数据模型

```
Project {
  id, name, description,
  startDate, endDate,
  region,              // 项目地区
  department,          // 部门识别方式
  claimMethod,         // single | multiple
  ownerId,             // 负责人
  acceptorId,          // 验收人
  requireSignature,    // 是否需要授权签名
  recycleHours,        // 回收时间（默认48小时）
  qcRules,             // 质检规则
  paymentTemplate,     // 报酬模板
  isActive,
  tasks[]              // 关联任务
}
```

#### 2.4 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| PROJ-001 | 创建项目 | POST `/api/projects` 含 name/region/claimMethod | 返回 201，项目创建成功 |
| PROJ-002 | 设置单次领取 | POST 项目 `claimMethod: "single"` | 项目 claimMethod 为 single |
| PROJ-003 | 设置多次领取 | POST 项目 `claimMethod: "multiple"` | 项目 claimMethod 为 multiple |
| PROJ-004 | 设置负责人和验收人 | POST 项目含 ownerId/acceptorId | 关联正确 |
| PROJ-005 | 开启授权签名 | POST 项目 `requireSignature: true` | 项目 requireSignature 为 true |
| PROJ-006 | 设置回收时间 | POST 项目 `recycleHours: 72` | 回收时间 72 小时 |
| PROJ-007 | 获取项目列表 | GET `/api/projects` | 返回项目数组 |
| PROJ-008 | 获取项目详情 | GET `/api/projects/:id` | 返回完整项目信息含 tasks |
| PROJ-009 | 更新项目 | PATCH `/api/projects/:id` | 更新成功 |
| PROJ-010 | 删除项目 | DELETE `/api/projects/:id` | 返回 200（soft delete） |
| PROJ-011 | 普通用户创建项目 | 采集员 Token POST `/api/projects` | 返回 403 Forbidden |

---

### 模块 3：任务配置 (Task)

#### 3.1 功能说明

任务属于项目下的具体采集工作单元，支持丰富的配置：

**基础配置：**
- 任务标题、描述、类型（audio/image/video/text）
- 难度等级（easy/medium/hard）
- 单价、总数量
- 每人最大领取数
- 截止时间

**文本上传：**
- 上传文本模板（本地文件或 UTF-8 格式 SML 文本）
- 批量导入文本

**质检配置：**
- 质检方式：一轮抽样 (spot_check) / 人工抽样 (manual_spot_check)
- 验收轮数
- 最低质量分、通过率要求

**音频配置：**
- 音频格式：WAV / PCM
- 声道：单声道 / 双声道
- 采样率：16000 Hz / 44100 Hz / 48000 Hz
- 噪音上限 (dB)
- 最大语音长度（秒）
- 静音区预留时间（毫秒）

**机器辅助功能：**
- 辅助识别
- 静音检测
- 声纹检测
- 增幅检测
- 信号检测

**任务分配：**
- 是否允许多次领取
- 验收轮数
- 回收时间（小时）
- 文本分配人数（0=自动计算）
- 是否复制多份文本分配给多名采集人员

#### 3.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/tasks` | 任务列表 | 登录 |
| GET | `/api/tasks/search` | 搜索任务 | 登录 |
| GET | `/api/tasks/:id` | 任务详情 | 登录 |
| POST | `/api/tasks` | 创建任务 | admin+ |
| PATCH | `/api/tasks/:id` | 更新任务 | admin+ |
| DELETE | `/api/tasks/:id` | 删除任务 | admin+ |
| POST | `/api/tasks/:id/claim` | 领取任务 | 采集员 |
| POST | `/api/tasks/:id/abandon` | 放弃任务 | 采集员 |
| GET | `/api/tasks/claims/mine` | 我的领取记录 | 采集员 |
| GET | `/api/tasks/claims/pending` | 待审核领取 | reviewer+ |
| POST | `/api/tasks/claims/:claimId/approve` | 审核通过 | reviewer+ |
| POST | `/api/tasks/claims/:claimId/reject` | 审核驳回 | reviewer+ |
| DELETE | `/api/tasks/data/all` | 清空任务数据 | super_admin |

#### 3.3 任务状态流转

```
draft → published → in_progress → completed → closed → archived
          ↑             |
          └─────────────┘  (回收后可重新发布)
```

#### 3.4 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| TASK-001 | 创建音频任务 | POST 含 type=audio, audioFormat=wav | 任务创建成功 |
| TASK-002 | 创建文本任务 | POST 含 type=text | 任务创建成功 |
| TASK-003 | 配置质检方式 | POST `qcMethod: "manual_spot_check"` | 质检方式为人工抽样 |
| TASK-004 | 配置音频参数 | POST 含 audioFormat/ channel/sampleRate | 参数正确保存 |
| TASK-005 | 配置噪音上限 | POST `noiseLimit: 50` | noiseLimit 为 50 |
| TASK-006 | 开启静音检测 | POST `silenceDetection: true` | 功能开启 |
| TASK-007 | 开启声纹检测 | POST `voiceprintDetection: true` | 功能开启 |
| TASK-008 | 设置回收时间 | POST `recycleHours: 72` | 回收时间 72 小时 |
| TASK-009 | 设置多次领取 | POST `allowMultipleClaims: true` | 允许多次领取 |
| TASK-010 | 设置文本复制分配 | POST `textCopyForAssign: true, textAssignCount: 5` | 每条文本复制 5 份 |
| TASK-011 | 采集员领取任务 | POST `/api/tasks/:id/claim` | 返回 claim 记录 |
| TASK-012 | 单次领取限制 | 已领取后再次 claim | 返回 400，不可重复领取 |
| TASK-013 | 放弃任务 | POST `/api/tasks/:id/abandon` | 任务释放回池中 |
| TASK-014 | 搜索任务 | GET `/api/tasks/search?keyword=xxx` | 返回匹配结果 |
| TASK-015 | 审核通过 | POST claims/:claimId/approve | 状态变为 approved |
| TASK-016 | 审核驳回 | POST claims/:claimId/reject | 状态变为 rejected |

---

### 模块 4：文本采集 (Text Collection)

#### 4.1 功能说明

文本采集模块管理采集任务中的文本条目：

- 文本内容管理（纯文本 / SML 格式）
- 文本模板上传
- 文本分配（平均分配 / 复制多份分配）
- 文本回收（超时未完成自动回收）
- 采集状态追踪

#### 4.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/text-collections` | 文本列表 | 登录 |
| GET | `/api/text-collections/stats/:taskId` | 文本采集统计 | 登录 |
| GET | `/api/text-collections/:id` | 文本详情 | 登录 |
| POST | `/api/text-collections` | 创建单条文本 | admin+ |
| POST | `/api/text-collections/batch` | 批量创建文本 | admin+ |
| POST | `/api/text-collections/upload-template/:taskId` | 上传文本模板 | admin+ |
| POST | `/api/text-collections/assign` | 分配文本 | admin+ |
| POST | `/api/text-collections/recycle` | 回收文本 | admin+ |
| PATCH | `/api/text-collections/:id` | 更新文本 | admin+ |
| DELETE | `/api/text-collections/:id` | 删除文本 | admin+ |

#### 4.3 文本状态流转

```
pending → assigned → collecting → completed
   ↑                    |
   └───── qc_failed ────┘  (质检失败回收)
```

#### 4.4 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| TEXT-001 | 创建单条文本 | POST 含 taskId/content | 文本创建成功，状态 pending |
| TEXT-002 | 批量创建文本 | POST `/batch` 含多条文本 | 全部创建成功 |
| TEXT-003 | 上传 SML 模板 | POST upload-template 上传 .sml 文件 | 解析并创建文本条目 |
| TEXT-004 | 上传纯文本模板 | POST upload-template 上传 .txt 文件 | 逐行创建文本条目 |
| TEXT-005 | 分配文本（平均） | POST assign 含 taskId | 文本平均分配给采集员 |
| TEXT-006 | 分配文本（复制） | POST assign 含 copyForAssign=true | 每条文本复制多份 |
| TEXT-007 | 回收文本 | POST recycle 含 taskId | 超时未完成的文本回收到 pending |
| TEXT-008 | 查看采集统计 | GET stats/:taskId | 返回各状态文本数量 |
| TEXT-009 | 更新文本内容 | PATCH 更新 content | 文本内容更新 |
| TEXT-010 | 删除文本 | DELETE /:id | 文本删除成功 |

---

### 模块 5：团队管理 (Team)

#### 5.1 功能说明

- 团队创建与管理
- 成员添加/移除
- 邀请链接（8位加入码，自动生成）
- 团队加入

#### 5.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/teams` | 团队列表 | 登录 |
| GET | `/api/teams/:id` | 团队详情 | 登录 |
| GET | `/api/teams/:id/members` | 团队成员列表 | 登录 |
| POST | `/api/teams` | 创建团队 | 登录 |
| PATCH | `/api/teams/:id` | 更新团队 | admin/队长 |
| DELETE | `/api/teams/:id` | 删除团队 | admin/队长 |
| POST | `/api/teams/:id/members` | 添加成员 | admin/队长 |
| DELETE | `/api/teams/:id/members/:memberId` | 移除成员 | admin/队长 |
| POST | `/api/teams/:id/invite` | 邀请加入（返回加入码） | admin/队长 |
| POST | `/api/teams/join` | 通过加入码加入团队 | 登录 |

#### 5.3 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| TEAM-001 | 创建团队 | POST 含 name/description | 团队创建成功，自动生成 joinCode |
| TEAM-002 | 添加成员 | POST /:id/members | 成员添加成功 |
| TEAM-003 | 移除成员 | DELETE /:id/members/:memberId | 成员移除成功 |
| TEAM-004 | 生成邀请 | POST /:id/invite | 返回 joinCode |
| TEAM-005 | 通过加入码加入 | POST /join 含 joinCode | 加入团队成功 |
| TEAM-006 | 错误加入码 | POST /join 含错误 joinCode | 返回 404 |
| TEAM-007 | 查看团队成员 | GET /:id/members | 返回成员列表 |
| TEAM-008 | 非队长删除团队 | 普通成员 DELETE /:id | 返回 403 |
| TEAM-009 | 删除团队 | 队长 DELETE /:id | 团队删除成功 |

---

### 模块 6：数据提交与质检 (Submission / QC)

#### 6.1 功能说明

- 采集员提交数据（录音文件 + 标注）
- 自动质检（QC）：噪音检测、静音检测、时长检测
- 人工质检：审核员审核通过/驳回
- 质检评分
- 不合格数据回收

#### 6.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/submissions` | 提交数据 | 采集员 |
| GET | `/api/submissions/mine` | 我的提交 | 采集员 |
| GET | `/api/submissions/pending-review` | 待审核列表 | reviewer+ |
| GET | `/api/submissions/all` | 所有提交 | admin+ |
| GET | `/api/submissions/:id` | 提交详情 | 登录 |
| PATCH | `/api/submissions/:id` | 更新提交 | 采集员 |
| DELETE | `/api/submissions/:id` | 删除提交 | admin+ |
| POST | `/api/submissions/:id/approve` | 审核通过 | reviewer+ |
| POST | `/api/submissions/:id/reject` | 审核驳回 | reviewer+ |

#### 6.3 提交状态流转

```
draft → submitted → qc_processing → qc_passed → pending_review → approved
                                       ↓                           ↓
                                   qc_failed ←─────────────── rejected
                                       ↓
                                   (回收重做)
```

#### 6.4 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| SUB-001 | 提交数据 | POST 含 taskId/fileIds/data | 提交成功，状态 submitted |
| SUB-002 | 查看我的提交 | GET /mine | 返回当前用户的提交列表 |
| SUB-003 | 待审核列表 | GET /pending-review | 返回待审核数据 |
| SUB-004 | 审核通过 | POST /:id/approve | 状态变为 approved |
| SUB-005 | 审核驳回 | POST /:id/reject 含 rejectReason | 状态变为 rejected |
| SUB-006 | 质检评分 | 提交后查看 qcScore | 返回质检分数 |
| SUB-007 | 质检失败回收 | qc_failed 的提交 | 可重新提交 |
| SUB-008 | 删除提交 | admin DELETE /:id | 提交删除 |

---

### 模块 7：文件管理 (File)

#### 7.1 功能说明

- 大文件分片上传（init → chunk → complete）
- 小文件直接上传
- 支持 MinIO / 本地存储
- 文件下载链接获取
- 文件删除

#### 7.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/files/init` | 初始化分片上传 | 登录 |
| POST | `/api/files/chunk` | 上传分片 | 登录 |
| POST | `/api/files/complete` | 完成分片上传 | 登录 |
| POST | `/api/files/upload` | 小文件直接上传 | 登录 |
| GET | `/api/files/:id` | 文件信息 | 登录 |
| GET | `/api/files/:id/download-url` | 获取下载链接 | 登录 |
| DELETE | `/api/files/:id` | 删除文件 | admin+/所有者 |

#### 7.3 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| FILE-001 | 小文件上传 | POST /upload 含文件 | 返回 fileId |
| FILE-002 | 大文件分片上传 | init → chunk(多次) → complete | 返回 fileId |
| FILE-003 | 获取下载链接 | GET /:id/download-url | 返回可访问 URL |
| FILE-004 | 删除文件 | DELETE /:id | 文件删除成功 |
| FILE-005 | 超大文件上传 | 上传 >500MB 文件 | 成功（nginx 配置 client_max_body_size） |

---

### 模块 8：分类管理 (Category)

#### 8.1 功能说明

- 任务分类的 CRUD
- 分类关联任务

#### 8.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/categories` | 分类列表 | 登录 |
| GET | `/api/categories/:id` | 分类详情 | 登录 |
| POST | `/api/categories` | 创建分类 | admin+ |
| PATCH | `/api/categories/:id` | 更新分类 | admin+ |
| DELETE | `/api/categories/:id` | 删除分类 | admin+ |

#### 8.3 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| CAT-001 | 创建分类 | POST 含 name | 分类创建成功 |
| CAT-002 | 分类列表 | GET /categories | 返回分类数组 |
| CAT-003 | 更新分类 | PATCH /:id | 更新成功 |
| CAT-004 | 删除分类 | DELETE /:id | 删除成功 |
| CAT-005 | 重复创建 | POST 同名分类 | 返回冲突或允许 |

---

### 模块 9：管理后台 (Admin)

#### 9.1 功能说明

- 数据统计概览（Dashboard）
- 任务/提交趋势
- 数据导出

#### 9.2 API 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/admin/stats` | 统计概览 | admin+ |
| GET | `/api/admin/stats/trends` | 趋势数据 | admin+ |
| GET | `/api/admin/export/tasks` | 导出任务信息 | admin+ |
| GET | `/api/admin/export/submissions` | 导出提交信息 | admin+ |
| GET | `/api/admin/export/audio-links` | 导出音频链接 | admin+ |

#### 9.3 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| ADMIN-001 | 统计概览 | GET /admin/stats | 返回用户数/任务数/提交数等 |
| ADMIN-002 | 趋势数据 | GET /admin/stats/trends | 返回按日趋势 |
| ADMIN-003 | 导出任务 | GET /admin/export/tasks | 下载表格/json |
| ADMIN-004 | 导出提交 | GET /admin/export/submissions | 下载表格/json |
| ADMIN-005 | 导出音频链接 | GET /admin/export/audio-links | 返回可播放链接列表 |
| ADMIN-006 | 采集员访问统计 | 采集员 Token GET /admin/stats | 返回 403 |

---

### 模块 10：APP 采集端

#### 10.1 功能说明

- 登录（手机号+密码、短信验证码）
- 服务器地址配置（APP 内切换，无需重编译）
- 任务浏览与搜索
- 任务领取/放弃
- 录音采集（WAV/PCM，可配置采样率/声道）
- 录音在线播放、编辑
- 数据提交
- 个人中心（提交记录、质量评分）
- 团队加入

#### 10.2 测试用例

| 编号 | 测试场景 | 操作步骤 | 预期结果 |
|------|---------|---------|---------|
| APP-001 | 登录 | 输入手机号+密码登录 | 登录成功，跳转首页 |
| APP-002 | 切换服务器 | 设置 → 服务器设置 → 输入新地址 | 连接测试通过，保存成功 |
| APP-003 | 浏览任务 | 首页任务列表 | 显示可领取任务 |
| APP-004 | 领取任务 | 点击领取按钮 | 任务出现在"我的任务" |
| APP-005 | 录音 | 进入任务 → 开始录音 | 录音正常，显示时长 |
| APP-006 | 播放录音 | 录音完成 → 播放 | 音频正常播放 |
| APP-007 | 提交数据 | 录音完成 → 提交 | 提交成功 |
| APP-008 | 查看提交记录 | 我的 → 提交记录 | 显示历史提交及状态 |
| APP-009 | 加入团队 | 输入加入码 | 加入成功 |
| APP-010 | 离线录制 | 断网状态下录音 | 本地保存，联网后可上传 |

---

## 三、量化参数配置表

| 参数类型 | 选项/数值 | 说明 |
|---------|----------|------|
| 任务领取方式 | `single` / `multiple` | 单次领取或多次领取 |
| 质检方式 | `spot_check` / `manual_spot_check` | 一轮抽样或人工抽样 |
| 音频格式 | `wav` / `pcm` | 常用音频格式 |
| 声道 | `mono` / `stereo` | 单声道或双声道 |
| 采样率 | `16000` / `44100` / `48000` Hz | 根据项目需求选择 |
| 噪音上限 | 用户自定义 (dB) | 限制录音噪音 |
| 最大语音长度 | 用户自定义 (秒) | 限制录音时长 |
| 静音区预留时间 | 用户自定义 (ms) | 录音前后静音缓冲 |
| 回收时间 | 默认 48 小时（可自定义） | 超时未完成任务自动回收 |
| 文本分配人数 | 0=自动计算，或指定数量 | 支持平均分配或复制多份分配 |
| 验收轮数 | 默认 1 轮 | 多轮验收提高质量 |
| 最低质量分 | 默认 60 | 低于此分的提交不通过 |
| 通过率要求 | 默认 0 | 质检通过率下限 |

---

## 四、端到端测试流程

### 4.1 完整采集流程测试

```
1. 管理员登录 → 创建项目 → 创建任务 → 上传文本 → 分配文本
2. 采集员登录 → 浏览任务 → 领取任务 → 录音 → 提交
3. 审核员登录 → 查看待审核 → 通过/驳回
4. 管理员登录 → 查看统计 → 导出数据
```

#### 详细步骤

**Step 1: 管理员创建项目**

```bash
# 登录获取 Token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800000000","password":"admin123"}'

# 创建项目
curl -X POST http://localhost:3000/api/projects \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "普通话语音采集项目",
    "description": "采集普通话语音数据",
    "region": "北京",
    "department": "语音部门",
    "claimMethod": "multiple",
    "requireSignature": true,
    "recycleHours": 72
  }'
```

**Step 2: 创建任务并配置**

```bash
# 创建任务
curl -X POST http://localhost:3000/api/tasks \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "句子朗读采集",
    "type": "audio",
    "projectId": "<project-id>",
    "totalQuantity": 100,
    "unitPrice": 1.00,
    "qcMethod": "manual_spot_check",
    "audioFormat": "wav",
    "audioChannel": "mono",
    "sampleRate": 16000,
    "noiseLimit": 50,
    "maxSpeechLength": 30,
    "silencePadding": 300,
    "silenceDetection": true,
    "allowMultipleClaims": true,
    "recycleHours": 48,
    "textCopyForAssign": true,
    "textAssignCount": 3
  }'
```

**Step 3: 上传文本并分配**

```bash
# 批量创建文本
curl -X POST http://localhost:3000/api/text-collections/batch \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "taskId": "<task-id>",
    "texts": [
      {"content": "今天天气真好"},
      {"content": "我明天要去北京出差"},
      {"content": "这个项目的进展很顺利"}
    ]
  }'

# 分配文本
curl -X POST http://localhost:3000/api/text-collections/assign \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"taskId": "<task-id>"}'
```

**Step 4: 采集员领取并提交**

```bash
# 采集员登录
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","password":"123456"}'

# 领取任务
curl -X POST http://localhost:3000/api/tasks/<task-id>/claim \
  -H "Authorization: Bearer <collector-token>"

# 上传录音文件
curl -X POST http://localhost:3000/api/files/upload \
  -H "Authorization: Bearer <collector-token>" \
  -F "file=@recording.wav"

# 提交数据
curl -X POST http://localhost:3000/api/submissions \
  -H "Authorization: Bearer <collector-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "taskId": "<task-id>",
    "claimId": "<claim-id>",
    "fileIds": ["<file-id>"],
    "data": {"textId": "<text-id>", "duration": 5.2}
  }'
```

**Step 5: 审核员审核**

```bash
# 审核员登录
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800000001","password":"reviewer123"}'

# 查看待审核
curl http://localhost:3000/api/submissions/pending-review \
  -H "Authorization: Bearer <reviewer-token>"

# 通过
curl -X POST http://localhost:3000/api/submissions/<submission-id>/approve \
  -H "Authorization: Bearer <reviewer-token>"
```

**Step 6: 管理员导出**

```bash
# 统计
curl http://localhost:3000/api/admin/stats \
  -H "Authorization: Bearer <admin-token>"

# 导出音频链接
curl http://localhost:3000/api/admin/export/audio-links \
  -H "Authorization: Bearer <admin-token>"
```

---

### 4.2 异常流程测试

| 编号 | 场景 | 操作 | 预期 |
|------|------|------|------|
| ERR-001 | 过期 Token | 使用过期 Token 请求 | 自动刷新或返回 401 |
| ERR-002 | 并发领取 | 多人同时领取同一任务 | 总领取数不超过 totalQuantity |
| ERR-003 | 重复提交 | 对同一 claim 重复提交 | 第二次返回错误 |
| ERR-004 | 超大文件 | 上传 >500MB 文件 | 成功（受 nginx 限制） |
| ERR-005 | 未领取就提交 | 未 claim 直接提交 | 返回 400 |
| ERR-006 | 被拉黑用户操作 | 黑名单用户领取任务 | 返回 403 |
| ERR-007 | 任务已关闭领取 | 关闭状态的任务 claim | 返回 400 |
| ERR-008 | 文本回收后重新分配 | recycle 后再 assign | 文本变为 pending 可重新分配 |

---

## 五、性能测试建议

| 测试项 | 指标 | 说明 |
|--------|------|------|
| 登录接口 | < 200ms | 并发 100 用户 |
| 任务列表 | < 500ms | 1000 条任务数据 |
| 文件上传 | > 10MB/s | 分片上传吞吐 |
| 大文件上传 | 成功率 99% | 500MB 文件 |
| 并发领取 | 无超卖 | 100 用户抢同一任务 |
| 数据导出 | < 5s | 10000 条记录 |

---

## 六、安全测试

| 编号 | 测试项 | 操作 | 预期 |
|------|--------|------|------|
| SEC-001 | SQL 注入 | 登录时 phone 字段输入 `' OR 1=1 --` | 返回 401，无数据泄露 |
| SEC-002 | XSS | 任务描述输入 `<script>alert(1)</script>` | 原样存储，前端转义显示 |
| SEC-003 | 越权访问 | 采集员 Token 访问 /api/admin/stats | 返回 403 |
| SEC-004 | Token 伪造 | 修改 Token payload | 返回 401 |
| SEC-005 | 暴力破解 | 同一手机号连续 10 次错误密码 | 触发限流 (throttle) |
| SEC-006 | 文件类型校验 | 上传 .exe 文件 | 拒绝或标记 |

---

## 七、部署验证清单

| 项目 | 验证方式 | 通过标准 |
|------|---------|---------|
| 后端启动 | `curl https://blackend.duanfukeji.com/` | 返回 JSON 含 name/version |
| API 文档 | 访问 `/api/docs` | Swagger 页面正常显示 |
| 管理后台 | 访问 `/admin/` | 登录页面正常显示 |
| 管理员登录 | 输入 13800000000 / admin123 | 登录成功进入 Dashboard |
| 数据库连接 | 创建项目 | 数据持久化 |
| 文件上传 | 上传音频文件 | 上传成功可播放 |
| SSL 证书 | HTTPS 访问 | 证书有效，无警告 |
| Docker 容器 | `docker ps` | 所有容器 running |
