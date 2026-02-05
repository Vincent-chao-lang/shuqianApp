# 书签设计 API 后端

基于 FastAPI + Claude Vision API 的书签设计后端服务。

## 功能特性

- 🎨 **AI视觉分析** - 使用Claude Vision API分析参考图片，提取设计元素
- 🖼️ **智能图像生成** - 使用Pillow生成高质量书签（72dpi预览 / 300dpi最终）
- 📐 **多种布局支持** - 左右布局、上下布局、居中聚焦、拼贴网格、全出血
- 🎭 **情绪风格识别** - 温暖治愈、清新自然、专业简约、活泼可爱等
- 🔄 **异步处理** - 基于async/await的高性能异步处理
- 🧹 **自动清理** - 定时清理临时文件，防止磁盘占用
- 📝 **完整文档** - Swagger UI自动生成的API文档

## 技术栈

- **框架**: FastAPI 0.115.0
- **图像处理**: Pillow 11.0.0
- **AI分析**: Anthropic Claude Vision API
- **数据验证**: Pydantic 2.9.2
- **异步运行**: Uvicorn
- **日志**: Loguru

## 项目结构

```
backend/
├── app/
│   ├── api/
│   │   ├── __init__.py
│   │   └── routes.py              # API路由定义
│   ├── core/
│   │   ├── __init__.py
│   │   └── config.py              # 配置管理
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py             # Pydantic数据模型
│   ├── services/
│   │   ├── __init__.py
│   │   ├── claude_analyzer.py     # Claude API调用
│   │   └── bookmark_generator.py  # 书签生成核心逻辑
│   ├── utils/
│   │   ├── __init__.py
│   │   └── helpers.py             # 辅助函数
│   ├── __init__.py
│   └── main.py                    # FastAPI应用入口
├── downloads/                     # 生成的书签文件
├── logs/                          # 日志文件
├── temp/                          # 临时文件
├── tests/                         # 测试文件
├── .env.example                   # 环境变量模板
├── requirements.txt               # Python依赖
├── run.py                         # 启动脚本
└── README.md                      # 本文档
```

## 快速开始

### 1. 环境要求

- Python 3.10+
- Claude API密钥（从 https://console.anthropic.com/ 获取）

### 2. 安装依赖

```bash
# 进入项目目录
cd backend

# 创建虚拟环境（推荐）
python3 -m venv venv
source venv/bin/activate  # Linux/macOS
# 或
venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt
```

### 3. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑.env文件，填入你的API密钥
# ANTHROPIC_API_KEY=your_actual_api_key_here
```

### 4. 启动服务

```bash
# 方式1: 使用run.py
python run.py

# 方式2: 直接使用uvicorn
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 方式3: 开发模式（自动重载）
python -m app.main
```

服务启动后访问：
- API文档: http://localhost:8000/docs
- ReDoc文档: http://localhost:8000/redoc
- 健康检查: http://localhost:8000/api/health

## API端点

### POST /api/analyze-reference
分析参考图片，提取设计元素

**请求:**
- Content-Type: multipart/form-data
- 参数: images (1-3张图片)

**响应:**
```json
{
  "layout": {
    "type": "left-right",
    "confidence": 0.95,
    "description": "左图右文布局"
  },
  "colors": {
    "primary": [{"hex": "#F5F5DC", "name": "米白"}],
    "palette_name": "温暖秋日",
    ...
  },
  ...
}
```

### POST /api/generate-preview
生成低分辨率预览图（72dpi）

**请求:**
```json
{
  "mood": "温暖治愈",
  "complexity": 3,
  "colors": ["#F5F5DC", "#8B7355"],
  "layout": "left-right"
}
```

**响应:**
```json
{
  "preview_url": "/downloads/preview_xxx.png",
  "width": 170,
  "height": 510
}
```

### POST /api/generate-final
生成高分辨率最终书签（300dpi）

**请求:**
- Content-Type: multipart/form-data
- request: JSON格式的请求参数
- user_photo: 用户上传的照片（可选）

**响应:**
```json
{
  "png_url": "/downloads/bookmark_xxx.png",
  "pdf_url": "/downloads/bookmark_xxx.pdf",
  "width": 709,
  "height": 2126,
  "dpi": 300
}
```

### GET /downloads/{filename}
下载生成的文件

### POST /api/cleanup
手动触发临时文件清理

## 配置说明

主要配置项（在.env或config.py中设置）：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| ANTHROPIC_API_KEY | Claude API密钥 | - |
| CLAUDE_MODEL | Claude模型版本 | claude-3-5-sonnet-20241022 |
| MAX_UPLOAD_SIZE | 最大上传大小 | 10MB |
| BOOKMARK_WIDTH_MM | 书签宽度 | 60mm |
| BOOKMARK_HEIGHT_MM | 书签高度 | 180mm |
| BLEED_MM | 出血区 | 3mm |
| FINAL_DPI | 最终输出DPI | 300 |
| TEMP_FILE_LIFETIME_HOURS | 临时文件存活时间 | 1小时 |
| CLEANUP_INTERVAL_MINUTES | 清理间隔 | 30分钟 |

## 开发

### 运行测试

```bash
pytest tests/
```

### 代码格式化

```bash
black app/
```

### 查看日志

日志文件位于 `logs/` 目录，按日期轮换：
```
logs/app_2025-01-13.log
```

## 部署

### 使用Docker（推荐）

```dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "run.py"]
```

### 使用systemd（Linux）

创建 `/etc/systemd/system/bookmark-api.service`:

```ini
[Unit]
Description=Bookmark Designer API
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/path/to/backend
Environment="PATH=/path/to/backend/venv/bin"
ExecStart=/path/to/backend/venv/bin/python run.py
Restart=always

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl start bookmark-api
sudo systemctl enable bookmark-api
```

## 故障排查

### 问题1: Claude API调用失败

**错误信息**: `ANTHROPIC_API_KEY is not set`

**解决方法**:
1. 确保已创建 `.env` 文件
2. 检查 `ANTHROPIC_API_KEY` 是否正确设置
3. 重启服务

### 问题2: 生成的图片字体显示异常

**原因**: 系统缺少中文字体

**解决方法**:
1. 安装中文字体（如文泉驿、思源黑体等）
2. 或在 `bookmark_generator.py` 的 `_load_font()` 中修改字体路径

### 问题3: 临时文件占用磁盘空间

**解决方法**:
1. 手动清理: `curl -X POST http://localhost:8000/api/cleanup`
2. 调整 `TEMP_FILE_LIFETIME_HOURS` 和 `CLEANUP_INTERVAL_MINUTES`

## 许可证

MIT License

## 联系方式

如有问题，请提交 Issue 或 Pull Request。
