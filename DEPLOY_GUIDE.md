# XCAI 端云智采 — 宝塔部署 & APK 编译指南

---

## 目录

- [一、宝塔面板部署](#一宝塔面板部署)
  - [1. 环境准备](#1-环境准备)
  - [2. 方案 A：PM2 直接部署（推荐轻量）](#2-方案-apm2-直接部署推荐轻量)
  - [3. 方案 B：Docker Compose 部署（推荐生产）](#3-方案-bdocker-compose-部署推荐生产)
  - [4. Nginx 反向代理配置](#4-nginx-反向代理配置)
  - [5. SSL 证书配置](#5-ssl-证书配置)
- [二、Docker 部署自定义端口](#二docker-部署自定义端口)
  - [1. 端口配置说明](#1-端口配置说明)
  - [2. APP 对接后端](#2-app-对接后端)
  - [3. 端口映射关系](#3-端口映射关系)
- [三、Flutter APP 编译 APK](#三flutter-app-编译-apk)
  - [1. 环境准备](#1-环境准备-1)
  - [2. 修改 API 地址](#2-修改-api-地址)
  - [3. 编译 Debug APK](#3-编译-debug-apk)
  - [4. 编译 Release APK（签名）](#4-编译-release-apk签名)
  - [5. 常见问题](#5-常见问题)

---

## 一、宝塔面板部署

### 1. 环境准备

在宝塔面板 **软件商店** 中安装以下组件：

| 组件 | 最低版本 | 说明 |
|------|---------|------|
| Nginx | 1.22+ | 反向代理 & 静态文件 |
| Node.js 版本管理器 | 20.x | 运行 NestJS 后端 |
| PM2 管理器 | 最新 | Node 进程守护 |
| PostgreSQL | 15+ | 生产数据库（可选，默认 SQLite） |
| Redis | 7+ | 缓存（可选） |

> **轻量部署**：只用 SQLite + 本地存储即可运行，无需 PostgreSQL / Redis / MinIO。

**安装 Node.js 20.x：**

宝塔 → 软件商店 → Node.js 版本管理器 → 安装 → 选择 v20.x → 设为默认

---

### 2. 方案 A：PM2 直接部署（推荐轻量）

#### 步骤 1：上传代码

```bash
# 方式一：Git 拉取（推荐）
cd /www/wwwroot
git clone <你的仓库地址> xcai
cd xcai

# 方式二：宝塔文件管理器上传 zip 包
# 上传到 /www/wwwroot/xcai 后解压
```

#### 步骤 2：构建后端

```bash
cd /www/wwwroot/xcai/server
npm install
npm run build
```

#### 步骤 3：构建 Admin 管理后台

```bash
cd /www/wwwroot/xcai/admin
npm install
npm run build
# 产物在 admin/dist/ 目录
```

#### 步骤 4：构建 Flutter Web（可选）

如需同时部署 Web 版 APP：

```bash
cd /www/wwwroot/xcai/app
flutter build web --base-href /app/
# 产物在 app/build/web/ 目录
```

#### 步骤 5：创建环境配置

```bash
cd /www/wwwroot/xcai/server
cat > .env.production << 'EOF'
# ===== 应用配置 =====
NODE_ENV=production
PORT=3000

# ===== 数据库配置 =====
# 开发/轻量：使用 SQLite
DB_TYPE=sqlite
DB_SQLITE_PATH=data/xcai.db
DB_SYNCHRONIZE=true
DB_LOGGING=false

# 生产：使用 PostgreSQL（推荐）
# DB_TYPE=postgres
# DB_HOST=localhost
# DB_PORT=5432
# DB_USERNAME=xcai_user
# DB_PASSWORD=你的强密码
# DB_DATABASE=xcai
# DB_SYNCHRONIZE=false
# DB_LOGGING=false

# ===== Redis 配置 =====
# REDIS_ENABLED=true
# REDIS_HOST=localhost
# REDIS_PORT=6379
# REDIS_PASSWORD=

# ===== 存储配置 =====
# 本地存储
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=data/uploads

# MinIO 对象存储（生产推荐）
# STORAGE_TYPE=minio
# MINIO_ENDPOINT=localhost
# MINIO_PORT=9000
# MINIO_ACCESS_KEY=minioadmin
# MINIO_SECRET_KEY=minioadmin
# MINIO_BUCKET=xcai
# MINIO_USE_SSL=false

# ===== JWT 配置 =====
JWT_SECRET=请修改为一个随机长字符串
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# ===== CORS =====
CORS_ORIGINS=https://your-domain.com

# ===== 短信配置 =====
SMS_PROVIDER=mock
# 阿里云短信
# SMS_PROVIDER=aliyun
# SMS_ACCESS_KEY_ID=
# SMS_ACCESS_KEY_SECRET=
# SMS_SIGN_NAME=
# SMS_TEMPLATE_CODE=
EOF
```

#### 步骤 6：初始化数据库 & 创建管理员

```bash
cd /www/wwwroot/xcai/server
npx ts-node src/seed.ts
# 输出：
# 🎉 超级管理员创建成功！
#    手机号: 13800000000
#    密码: admin123
```

> ⚠️ 请在首次登录后立即修改默认密码！

#### 步骤 7：PM2 启动后端

宝塔 → 软件商店 → PM2 管理器 → 添加项目：

| 项目 | 值 |
|------|-----|
| 启动文件 | `/www/wwwroot/xcai/server/dist/main.js` |
| 运行目录 | `/www/wwwroot/xcai/server` |
| 项目名称 | `xcai-server` |
| Node版本 | v20.x |

或命令行启动：

```bash
cd /www/wwwroot/xcai/server
pm2 start dist/main.js --name xcai-server --node-args="--max-old-space-size=512"
pm2 save
pm2 startup
```

验证后端是否正常：

```bash
curl http://localhost:3000/api/auth/login -X POST \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800000000","password":"admin123"}'
```

---

### 3. 方案 B：Docker Compose 部署（推荐生产）

#### 步骤 1：安装 Docker

宝塔 → 软件商店 → Docker管理器 → 安装

#### 步骤 2：配置环境变量

```bash
cd /www/wwwroot/xcai/deploy
cp .env.example .env
```

编辑 `.env` 文件：

```env
DB_PASSWORD=你的PostgreSQL强密码
MINIO_ACCESS_KEY=你的MinIO访问密钥
MINIO_SECRET_KEY=你的MinIO密钥
JWT_SECRET=请修改为一个随机长字符串
```

#### 步骤 3：修改 Nginx 配置

编辑 `deploy/nginx/conf.d/default.conf`，将 `server` 改为你的域名：

```nginx
server {
    listen 80;
    server_name your-domain.com;
    # ... 其余配置保持不变
}
```

> **注意**：Docker Compose 方案中需要更新 nginx 配置，添加 `/app/` 和 `/admin/` 的 location 块。参考下方 Nginx 配置章节。

#### 步骤 4：启动服务

```bash
cd /www/wwwroot/xcai/deploy
docker-compose up -d
```

查看日志：

```bash
docker-compose logs -f server
```

---

### 4. Nginx 反向代理配置

在宝塔中：网站 → 添加站点 → 设置域名 → 反向代理

或手动配置 Nginx：

**宝塔方式（推荐）：**

1. 网站 → 添加站点 → 填入域名（如 `xcai.example.com`）
2. 站点设置 → 反向代理 → 添加反向代理：
   - 代理名称：`xcai-api`
   - 目标URL：`http://127.0.0.1:3000`
   - 发送域名：`$host`

3. 站点设置 → 配置文件 → 替换为以下内容：

```nginx
server {
    listen 80;
    listen 443 ssl http2;
    server_name xcai.example.com;

    # SSL 证书（宝塔自动管理，或手动配置）
    # ssl_certificate     /www/server/ssl/xcai.example.com/fullchain.pem;
    # ssl_certificate_key /www/server/ssl/xcai.example.com/privkey.pem;

    # 上传文件大小限制
    client_max_body_size 500M;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    # ===== API 反向代理 =====
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # ===== Swagger API 文档 =====
    location /api/docs {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # ===== 上传文件访问 =====
    location /storage/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # ===== Admin 管理后台 =====
    location /admin/ {
        alias /www/wwwroot/xcai/admin/dist/;
        index index.html;
        try_files $uri $uri/ /admin/index.html;
    }

    # ===== Flutter Web APP =====
    location /app/ {
        alias /www/wwwroot/xcai/app/build/web/;
        index index.html;
        try_files $uri $uri/ /app/index.html;
    }

    # ===== 根路径重定向到 Admin =====
    location = / {
        return 302 /admin/;
    }
}
```

> ⚠️ **关键点**：`alias` 末尾必须有 `/`，`try_files` 中的 fallback 路径需要包含前缀（如 `/admin/index.html`）。

---

### 5. SSL 证书配置

**宝塔一键配置（推荐）：**

1. 网站 → 你的站点 → SSL → Let's Encrypt
2. 勾选域名 → 申请
3. 开启强制 HTTPS

**手动配置：**

```nginx
server {
    listen 443 ssl http2;
    server_name xcai.example.com;

    ssl_certificate     /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # ... 其余 location 配置同上
}

server {
    listen 80;
    server_name xcai.example.com;
    return 301 https://$host$request_uri;
}
```

---

## 二、Docker 部署自定义端口

### 选择部署模式

| 模式 | 配置文件 | 适用场景 | 说明 |
|------|---------|---------|------|
| **宿主机 Nginx（推荐）** | `docker-compose.host-nginx.yml` | 服务器已有 Nginx（宝塔） | 去掉 Docker 内 Nginx，避免双重代理 |
| 轻量部署 | `docker-compose.lite.yml` | 测试/小规模 | 仅 Server 容器，SQLite + 本地存储 |
| Docker 内 Nginx | `docker-compose.yml` | 全新服务器 | 包含完整 Nginx + 全套服务 |

---

### 方案 A：宿主机 Nginx（服务器已有 Nginx / 宝塔）

**架构：** 宝塔 Nginx (80/443) → Docker Server (3000)

```
┌──────────────────────────────────────────────────┐
│  客户端                                          │
│  APP ──→ https://cai.lhwebs.com/api/             │
│  Admin ──→ https://cai.lhwebs.com/admin/         │
│                    │                              │
│                    ▼                              │
│  ┌──────────────────────────────┐                │
│  │  宝塔 Nginx (宿主机 80/443)  │  ← SSL 证书    │
│  └──────┬──────────┬────────────┘                │
│         │          │                              │
│    /api/│    /admin/│ /app/                       │
│         ▼          ▼                              │
│  ┌──────────┐  ┌─────────────────┐               │
│  │  Docker  │  │  宿主机静态文件  │               │
│  │  Server  │  │  admin/dist/    │               │
│  │  :3000   │  │  app/build/web/ │               │
│  └────┬─────┘  └─────────────────┘               │
│       │                                           │
│  ┌────┼─────────────┐                            │
│  ▼    ▼       ▼      │                            │
│  PG   Redis  MinIO   │                            │
│  (容器内网，不暴露端口)│                            │
└──────────────────────────────────────────────────┘
```

#### 步骤 1：启动 Docker 服务

```bash
cd /www/wwwroot/xcai/deploy
cp .env.example .env
```

编辑 `.env`，关键配置：

```env
# 后端端口，宝塔 Nginx 反向代理目标
SERVER_PORT=3000

# 以下端口不需要暴露（留空或删除对应行）
POSTGRES_PORT=
REDIS_PORT=
MINIO_API_PORT=
MINIO_CONSOLE_PORT=

# 数据库密码
DB_PASSWORD=你的强密码
JWT_SECRET=请修改为随机长字符串
```

启动：

```bash
docker-compose -f docker-compose.host-nginx.yml up -d
```

#### 步骤 2：宝塔 Nginx 配置

1. 宝塔 → 网站 → 添加站点 → 填入域名 `cai.lhwebs.com`
2. 站点设置 → 配置文件 → 替换为：

```nginx
server {
    listen 80;
    listen 443 ssl http2;
    server_name cai.lhwebs.com;

    # SSL（宝塔自动管理，或手动配置）
    # ssl_certificate     /www/server/ssl/cai.lhwebs.com/fullchain.pem;
    # ssl_certificate_key /www/server/ssl/cai.lhwebs.com/privkey.pem;

    client_max_body_size 500M;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    # ===== API 反向代理 → Docker Server =====
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Swagger API 文档
    location /api/docs {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 上传文件访问
    location /storage/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # ===== Admin 管理后台（宿主机静态文件）=====
    location /admin/ {
        alias /www/wwwroot/xcai/admin/dist/;
        index index.html;
        try_files $uri $uri/ /admin/index.html;
    }

    # ===== Flutter Web APP（宿主机静态文件）=====
    location /app/ {
        alias /www/wwwroot/xcai/app/build/web/;
        index index.html;
        try_files $uri $uri/ /app/index.html;
    }

    # 根路径重定向到 Admin
    location = / {
        return 302 /admin/;
    }
}
```

#### 步骤 3：SSL 证书

宝塔 → 你的站点 → SSL → Let's Encrypt → 申请 → 开启强制 HTTPS

#### 步骤 4：APP 编译对接

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://cai.lhwebs.com/api
```

> 80/443 端口可省略。如使用自定义端口（如 8443），则：
> `--dart-define=API_BASE_URL=https://cai.lhwebs.com:8443/api`

---

### 方案 B：轻量部署（SQLite + 本地存储）

仅一个 Server 容器，配合宿主机 Nginx：

```bash
cd /www/wwwroot/xcai/deploy
cp .env.example .env
# 编辑 .env 设置 JWT_SECRET
docker-compose -f docker-compose.lite.yml up -d
```

Nginx 配置与方案 A 完全相同。

---

### 方案 C：Docker 内 Nginx（全新服务器）

```
┌──────────────────────────────────────────────────┐
│  客户端                                          │
│  APP ──→ https://cai.lhwebs.com/api/             │
│                    │                              │
│                    ▼ NGINX_HTTP_PORT=80           │
│  ┌──────────────────────────────┐                │
│  │  Docker Nginx (容器内 80)    │                │
│  └──────┬───────────────────────┘                │
│         │ 内部网络                                │
│  ┌──────┼──────────────┐                         │
│  ▼      ▼       ▼      │                         │
│  Server MinIO  静态文件 │                         │
│  :3000  :9000  admin/app│                         │
│  ┌──────┼──────────────┐                         │
│  ▼      ▼       ▼      │                         │
│  PG     Redis  data/   │                         │
└──────────────────────────────────────────────────┘
```

```bash
cd deploy
cp .env.example .env
# 编辑 .env
docker-compose up -d
```

端口配置：

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `NGINX_HTTP_PORT` | 80 | Nginx HTTP 端口 |
| `NGINX_HTTPS_PORT` | 443 | Nginx HTTPS 端口 |
| `SERVER_PORT` | 3000 | 后端 API（调试用） |
| `POSTGRES_PORT` | 5432 | PostgreSQL（可不暴露） |
| `REDIS_PORT` | 6379 | Redis（可不暴露） |
| `MINIO_API_PORT` | 9000 | MinIO API |
| `MINIO_CONSOLE_PORT` | 9001 | MinIO 控制台 |

---

### APP 对接后端

APP 的 `API_BASE_URL` 必须指向 **宿主机 Nginx 对外地址**，不直接访问 Docker 内部：

| 部署方式 | APP 编译参数 |
|---------|-------------|
| 宿主机 Nginx (443) | `--dart-define=API_BASE_URL=https://cai.lhwebs.com/api` |
| 宿主机 Nginx (自定义端口) | `--dart-define=API_BASE_URL=https://cai.lhwebs.com:8443/api` |
| Docker Nginx (8080) | `--dart-define=API_BASE_URL=http://your-ip:8080/api` |
| 内网 HTTP | `--dart-define=API_BASE_URL=http://192.168.1.100:3000/api` |

> **Flutter Web 版**（部署在 `/app/` 下）自动使用相对路径 `/api`，无需配置。

APP 内「设置 → 服务器设置」可动态切换 API 地址，无需重新编译。

---

### 端口映射速查

| 场景 | .env 配置 | APP API_BASE_URL |
|------|----------|-----------------|
| 宝塔 + HTTPS | `SERVER_PORT=3000` | `https://cai.lhwebs.com/api` |
| 宝塔 + 自定义端口 | `SERVER_PORT=3000` | `https://cai.lhwebs.com:8443/api` |
| Docker Nginx | `NGINX_HTTP_PORT=8080` | `http://your-ip:8080/api` |
| 直连后端(调试) | `SERVER_PORT=3000` | `http://your-ip:3000/api` |

---

## 三、Flutter APP 编译 APK

### 1. 环境准备

#### 安装 Flutter SDK

```bash
# 下载 Flutter SDK
cd /opt
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="/opt/flutter/bin:$PATH"

# 初始化
flutter doctor

# 确认 Android toolchain 就绪
flutter doctor --android-licenses
```

#### 安装 Android SDK

方式一：安装 Android Studio（推荐可视化操作）

方式二：命令行安装

```bash
# 下载 Android SDK command-line tools
mkdir -p /opt/android-sdk
cd /opt/android-sdk
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-*.zip
mkdir latest
mv cmdline-tools/* latest/cmdline-tools/ 2>/dev/null || true

# 设置环境变量
export ANDROID_HOME=/opt/android-sdk
export PATH="$ANDROID_HOME/latest/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# 安装必要组件
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# 接受许可
yes | sdkmanager --licenses
```

#### 配置 local.properties

```bash
cd /path/to/xcai/app
echo "flutter.sdk=/opt/flutter" > android/local.properties
# 如果使用 ANDROID_HOME 环境变量，无需额外配置
```

#### 检查环境

```bash
cd /path/to/xcai/app
flutter doctor -v
```

确认输出中：
- ✅ Flutter
- ✅ Android toolchain
- ✅ Android Studio（如果安装了）

---

### 2. 修改 API 地址

APP 默认连接 `10.0.2.2:4000`（Android 模拟器），正式部署需要修改为你的服务器地址。

#### 方式一：编译参数（推荐，无需改代码）

```bash
flutter build apk \
  --dart-define=API_BASE_URL=https://xcai.example.com/api
```

#### 方式二：修改源码

编辑 `app/lib/core/constants/app_constants.dart`：

```dart
String get defaultApiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;

  if (kIsWeb) return '/api';

  // 正式服务器地址
  return 'https://xcai.example.com/api';
}
```

#### 方式三：APP 内设置

APP 运行后可在「设置 → 服务器设置」中动态切换 API 地址，无需重新编译。

---

### 3. 编译 Debug APK

适用于测试阶段，无需签名：

```bash
cd /path/to/xcai/app

# 获取依赖
flutter pub get

# 编译 Debug APK
flutter build apk --debug \
  --dart-define=API_BASE_URL=https://xcai.example.com/api

# 产物路径
ls -la build/app/outputs/flutter-apk/app-debug.apk
```

安装到手机：

```bash
flutter install --debug
# 或
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

### 4. 编译 Release APK（签名）

#### 4.1 创建签名密钥

```bash
# 创建 keystore 目录
mkdir -p /path/to/xcai/app/android/keystore

# 生成签名密钥
keytool -genkeypair \
  -v \
  -keystore /path/to/xcai/app/android/keystore/xcai-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 36500 \
  -alias xcai \
  -storepass 你的keystore密码 \
  -keypass 你的key密码 \
  -dname "CN=XCAI, OU=Dev, O=YourCompany, L=City, ST=Province, C=CN"
```

> ⚠️ **请妥善保管 keystore 文件和密码！** 丢失后无法更新 APP！

#### 4.2 配置签名信息

创建 `app/android/key.properties`：

```properties
storePassword=你的keystore密码
keyPassword=你的key密码
keyAlias=xcai
storeFile=keystore/xcai-release.jks
```

#### 4.3 修改 build.gradle

编辑 `app/android/app/build.gradle`，替换为：

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

// 加载签名配置
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '0.1.0'
}

android {
    namespace = "com.xcai.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.xcai.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

flutter {
    source = "../.."
}

dependencies {}
```

#### 4.4 创建 ProGuard 规则

创建 `app/android/app/proguard-rules.pro`：

```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Dio
-dontwarn com.squareup.okhttp.**
-keep class com.squareup.okhttp.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*

# Model classes
-keep class com.xcai.app.** { *; }
```

#### 4.5 添加网络权限

确认 `app/android/app/src/main/AndroidManifest.xml` 中有网络权限：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 网络权限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- 录音权限 -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

    <application
        android:usesCleartextTraffic="true"
        ...>
        ...
    </application>
</manifest>
```

> `android:usesCleartextTraffic="true"` 允许 HTTP 请求（仅开发/内网环境需要，HTTPS 不需要）

#### 4.6 编译 Release APK

```bash
cd /path/to/xcai/app

# 清理之前的构建
flutter clean
flutter pub get

# 编译 Release APK
flutter build apk --release \
  --dart-define=API_BASE_URL=https://xcai.example.com/api

# 产物路径
ls -la build/app/outputs/flutter-apk/app-release.apk
```

#### 4.7 编译 App Bundle（上传 Google Play）

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://xcai.example.com/api

# 产物路径
ls -la build/app/outputs/bundle/release/app-release.aab
```

---

### 5. 常见问题

#### Q1: `flutter doctor` 提示 Android licenses 未接受

```bash
flutter doctor --android-licenses
# 逐个输入 y 接受
```

#### Q2: 编译报错 `minSdkVersion` 冲突

编辑 `app/android/app/build.gradle`，手动指定：

```gradle
android {
    defaultConfig {
        minSdk = 21  // 或更高
    }
}
```

#### Q3: 编译报错 NDK 版本不匹配

```bash
sdkmanager "ndk;28.2.13676358"
# 或修改 build.gradle 中的 ndkVersion 为已安装的版本
```

#### Q4: APK 安装后闪退

1. 检查 `--dart-define=API_BASE_URL` 是否正确
2. 检查服务器是否可从手机网络访问
3. 查看日志：`adb logcat | grep -i flutter`

#### Q5: 宝塔 Nginx `try_files` 不生效

确保使用 `alias` 而非 `root`，且 alias 路径末尾带 `/`：

```nginx
# ✅ 正确
location /admin/ {
    alias /www/wwwroot/xcai/admin/dist/;
    try_files $uri $uri/ /admin/index.html;
}

# ❌ 错误
location /admin/ {
    root /www/wwwroot/xcai/admin/dist;  # 会导致路径拼接错误
}
```

#### Q6: PM2 启动后立即停止

```bash
# 查看错误日志
pm2 logs xcai-server --err

# 常见原因：端口被占用
lsof -i :3000
kill -9 <PID>

# 或修改 .env.production 中的 PORT
```

#### Q7: 文件上传 413 错误

在 Nginx 配置中增加：

```nginx
client_max_body_size 500M;
```

---

## 快速部署命令速查

```bash
# ===== 服务器部署 =====
cd /www/wwwroot/xcai/server
npm install && npm run build
npx ts-node src/seed.ts               # 首次：初始化数据库
pm2 start dist/main.js --name xcai-server
pm2 save && pm2 startup

cd /www/wwwroot/xcai/admin
npm install && npm run build

# ===== APK 编译 =====
cd /path/to/xcai/app
flutter clean && flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL=https://xcai.example.com/api

# APK 位置：build/app/outputs/flutter-apk/app-release.apk
```

---

## 目录结构总览

```
/www/wwwroot/xcai/
├── server/                 # NestJS 后端
│   ├── dist/              # 编译产物
│   ├── data/              # SQLite 数据库 + 上传文件
│   │   ├── xcai.db
│   │   └── uploads/
│   └── .env.production    # 环境变量
├── admin/                  # React 管理后台
│   └── dist/              # 编译产物（Nginx 直接服务）
├── app/                    # Flutter APP
│   ├── build/web/         # Web 编译产物（可选部署）
│   ├── build/app/outputs/ # APK 编译产物
│   └── android/           # Android 原生配置
└── deploy/                 # Docker 部署配置
    ├── docker-compose.yml
    └── nginx/
```
