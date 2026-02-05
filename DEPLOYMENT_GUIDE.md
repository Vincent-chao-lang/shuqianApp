# BookmarkDesigner 项目部署指南

## 📋 项目架构总览

### 前端（iOS App）
- **路径**: `/Users/qiupengchao/lab/shuqian/BookmarkDesigner/`
- **技术栈**: SwiftUI + iOS 17+
- **核心功能**:
  - 图片上传（相册/相机）
  - AI分析展示
  - 文字编辑与定位
  - 书签生成与分享

### 后端（FastAPI）
- **路径**: `/Users/qiupengchao/lab/shuqianApp/backend/`
- **技术栈**: Python 3.10+ + FastAPI
- **核心功能**:
  - 图片分析（GLM-4-Vision / Claude）
  - 文生图生成（GLM CogView-3-Plus）
  - 书签生成（PIL）
  - 文件下载服务

---

## 🚀 腾讯云轻量化服务器部署步骤

### 第一步：服务器连接与基础配置

#### 1.1 连接到服务器
```bash
# SSH连接到腾讯云服务器
ssh root@YOUR_SERVER_IP

# 或使用密钥文件
ssh -i /path/to/your/key.pem root@YOUR_SERVER_IP
```

#### 1.2 更新系统
```bash
# 更新软件包
sudo apt update && sudo apt upgrade -y

# 安装必要工具
sudo apt install -y git curl wget vim htop
```

#### 1.3 配置防火墙（腾讯云控制台）
在腾讯云控制台配置安全组规则，开放以下端口：
- **22** - SSH
- **80** - HTTP
- **443** - HTTPS
- **8000** - 后端API（开发环境，可选）

---

### 第二步：安装Python环境

#### 2.1 安装Python 3.10+
```bash
# 安装Python 3.10
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install -y python3.10 python3.10-venv python3-pip

# 验证安装
python3.10 --version
```

#### 2.2 安装系统依赖
```bash
# 安装图像处理库依赖
sudo apt install -y \
    python3.10-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libglib2.0-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libfreetype6-dev \
    libwebp-dev \
    libopenjp2-7-dev

# 安装其他依赖
sudo apt install -y \
    libmagic1 \
    nginx \
    certbot \
    python3-certbot-nginx
```

---

### 第三步：部署后端应用

#### 3.1 创建项目目录
```bash
# 创建应用目录
sudo mkdir -p /opt/bookmark-designer
sudo chown -R $USER:$USER /opt/bookmark-designer
cd /opt/bookmark-designer
```

#### 3.2 上传代码到服务器

**方法A：使用Git（推荐）**
```bash
# 如果代码在Git仓库
git clone YOUR_GIT_REPO_URL .
```

**方法B：使用SCP**
```bash
# 在本地Mac上执行
cd /Users/qiupengchao/lab/shuqianApp
scp -r backend root@YOUR_SERVER_IP:/opt/bookmark-designer/
```

**方法C：使用rsync**
```bash
# 在本地Mac上执行
rsync -avz --progress \
  /Users/qiupengchao/lab/shuqianApp/backend/ \
  root@YOUR_SERVER_IP:/opt/bookmark-designer/backend
```

#### 3.3 创建Python虚拟环境
```bash
cd /opt/bookmark-designer/backend
python3.10 -m venv venv
source venv/bin/activate
```

#### 3.4 安装Python依赖
```bash
# 升级pip
pip install --upgrade pip

# 安装依赖
pip install -r requirements.txt
```

#### 3.5 配置环境变量
```bash
# 创建环境配置文件
cat > .env << 'EOF'
# API密钥配置（请替换为您的实际密钥）
ZHIPU_AI_API_KEY=your_zhipu_api_key_here
ANTHROPIC_API_KEY=your_anthropic_key_here

# CORS配置
CORS_ORIGINS=["*"]

# 服务器配置
HOST=0.0.0.0
PORT=8000

# 日志级别
LOG_LEVEL=INFO
EOF

# 设置文件权限
chmod 600 .env
```

---

### 第四步：配置Systemd服务

#### 4.1 创建systemd服务文件
```bash
sudo vim /etc/systemd/system/bookmark-api.service
```

#### 4.2 服务文件内容
```ini
[Unit]
Description=BookmarkDesigner API
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/bookmark-designer/backend
Environment="PATH=/opt/bookmark-designer/backend/venv/bin"
ExecStart=/opt/bookmark-designer/backend/venv/bin/gunicorn app.main:app \
  --workers 2 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --timeout 300 \
  --access-logfile /var/log/bookmark-api/access.log \
  --error-logfile /var/log/bookmark-api/error.log
ExecStop=/bin/kill -s TERM $MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### 4.3 创建日志目录
```bash
sudo mkdir -p /var/log/bookmark-api
sudo chown -R www-data:www-data /var/log/bookmark-api
```

#### 4.4 启动服务
```bash
# 重新加载systemd配置
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start bookmark-api

# 设置开机自启
sudo systemctl enable bookmark-api

# 查看服务状态
sudo systemctl status bookmark-api

# 查看日志
sudo journalctl -u bookmark-api -f
```

---

### 第五步：配置Nginx反向代理

#### 5.1 创建Nginx配置
```bash
sudo vim /etc/nginx/sites-available/bookmark-designer
```

#### 5.2 Nginx配置内容
```nginx
# 上游服务器定义
upstream bookmark_backend {
    server 127.0.0.1:8000;
}

# HTTP服务器配置（重定向到HTTPS）
server {
    listen 80;
    server_name your-domain.com;  # 替换为您的域名或服务器IP

    # 如果有域名，重定向到HTTPS
    # return 301 https://$server_name$request_uri;

    # 如果没有域名，直接代理
    client_max_body_size 20M;

    location / {
        proxy_pass http://bookmark_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API路由
    location /api/ {
        proxy_pass http://bookmark_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时设置（文生图可能需要较长时间）
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }

    # 静态文件下载
    location /downloads/ {
        alias /opt/bookmark-designer/backend/downloads/;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
}
```

#### 5.3 启用配置
```bash
# 创建符号链接
sudo ln -s /etc/nginx/sites-available/bookmark-designer /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启Nginx
sudo systemctl restart nginx
```

---

### 第六步：配置SSL证书（可选但推荐）

#### 6.1 使用Let's Encrypt免费证书
```bash
# 如果有域名
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

#### 6.2 如果没有域名，使用自签名证书（仅用于测试）
```bash
# 生成自签名证书
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/bookmark-selfsigned.key \
  -out /etc/ssl/certs/bookmark-selfsigned.crt

# 修改Nginx配置使用HTTPS
sudo vim /etc/nginx/sites-available/bookmark-designer
```

添加HTTPS server块：
```nginx
server {
    listen 443 ssl;
    server_name your-server-ip;

    ssl_certificate /etc/ssl/certs/bookmark-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/bookmark-selfsigned.key;

    # ... 其余配置同上
}
```

---

### 第七步：配置iOS客户端

#### 7.1 修改API地址
在Xcode中打开 `NetworkManager.swift`，修改 `baseURL`：

```swift
// 开发环境（本地测试）
// private let baseURL = "http://localhost:8000/api"

// 生产环境（腾讯云服务器）
private let baseURL = "http://YOUR_SERVER_IP/api"  // HTTP
// private let baseURL = "https://your-domain.com/api"  // HTTPS
```

#### 7.2 配置ATS（如果使用HTTP）
在Xcode项目中：
1. 选择项目target
2. Info标签
3. 添加 `NSAppTransportSecurity`
4. 设置 `NSAllowsArbitraryLoads` 为 `YES`

---

### 第八步：监控与维护

#### 8.1 查看日志
```bash
# 应用日志
sudo journalctl -u bookmark-api -f

# Nginx日志
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# 应用详细日志
tail -f /opt/bookmark-designer/backend/logs/app.log
```

#### 8.2 性能监控
```bash
# 安装监控工具
sudo apt install -y htop iotop

# 查看系统资源
htop

# 查看磁盘使用
df -h

# 查看内存使用
free -h
```

#### 8.3 更新应用
```bash
cd /opt/bookmark-designer/backend
git pull  # 如果使用Git
# 或重新上传代码

source venv/bin/activate
pip install -r requirements.txt

sudo systemctl restart bookmark-api
```

---

## 🧪 测试部署

### 测试后端API
```bash
# 测试健康检查
curl http://YOUR_SERVER_IP:8000/health

# 测试CORS
curl -X OPTIONS http://YOUR_SERVER_IP:8000/api/analyze \
  -H "Origin: *" \
  -H "Access-Control-Request-Method: POST"

# 测试图片分析（如果有测试图片）
curl -X POST http://YOUR_SERVER_IP:8000/api/analyze \
  -F "images=@test.jpg"
```

### 测试iOS客户端
1. 修改 `NetworkManager.swift` 中的 `baseURL`
2. 在真机上运行App
3. 测试完整流程：上传 → 分析 → 生成 → 分享

---

## 📊 服务器资源建议

### 轻量化服务器配置
- **CPU**: 2核
- **内存**: 2GB+
- **存储**: 40GB+
- **带宽**: 5Mbps+
- **操作系统**: Ubuntu 22.04 LTS

### 预估负载
- **并发用户**: 10-50人
- **日生成量**: 200-1000张书签
- **响应时间**:
  - 图片分析: 3-10秒
  - 文生图: 10-30秒
  - 书签生成: 1-3秒

---

## 🔒 安全建议

1. **配置防火墙**
```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

2. **定期更新**
```bash
# 设置自动安全更新
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

3. **备份配置**
```bash
# 备份代码和配置
tar -czf bookmark-backup-$(date +%Y%m%d).tar.gz /opt/bookmark-designer

# 备份到云存储（可选）
# scp bookmark-backup-*.tar.gz user@backup-server:/backups/
```

---

## 📞 故障排查

### 问题1：服务无法启动
```bash
# 查看详细日志
sudo journalctl -xe -u bookmark-api

# 检查端口占用
sudo netstat -tlnp | grep 8000

# 检查文件权限
ls -la /opt/bookmark-designer/backend
```

### 问题2：502 Bad Gateway
```bash
# 检查后端服务是否运行
sudo systemctl status bookmark-api

# 检查Nginx配置
sudo nginx -t

# 查看Nginx错误日志
sudo tail -f /var/log/nginx/error.log
```

### 问题3：图片生成失败
```bash
# 检查API密钥配置
cat /opt/bookmark-designer/backend/.env

# 查看应用日志
tail -f /opt/bookmark-designer/backend/logs/app.log

# 测试API连接
curl -X GET https://open.bigmodel.cn/api/paas/v4/chat/completions
```

---

## 📈 扩展建议

### 当流量增长时
1. **增加worker数量**
```ini
ExecStart=/opt/bookmark-designer/backend/venv/bin/gunicorn app.main:app \
  --workers 4 \  # 增加到4个worker
  ...
```

2. **使用Supervisor管理进程**
```bash
sudo apt install -y supervisor
```

3. **添加Redis缓存**
```bash
sudo apt install -y redis-server
sudo systemctl start redis
```

4. **使用CDN加速**
   - 腾讯云CDN
   - 静态资源缓存

---

## ✅ 部署清单

- [ ] 服务器基础配置
- [ ] Python环境安装
- [ ] 代码上传到服务器
- [ ] 虚拟环境创建
- [ ] 依赖安装
- [ ] 环境变量配置
- [ ] Systemd服务配置
- [ ] Nginx反向代理配置
- [ ] SSL证书配置（可选）
- [ ] 防火墙配置
- [ ] iOS客户端API地址修改
- [ ] 端到端测试
- [ ] 监控配置

---

**祝部署顺利！** 🚀

遇到问题请参考故障排查部分或检查日志文件。
