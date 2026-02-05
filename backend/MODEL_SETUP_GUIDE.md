# 多模型配置指南

本文档说明如何配置和使用三个视觉AI模型：GLM、Qwen和Claude。

## 📋 模型对比

| 模型 | 提供商 | 价格 | 特点 | 推荐场景 |
|------|--------|------|------|---------|
| **GLM-4V-Flash** | 智谱AI | **免费** | 中文优化，完全免费 | 开发测试、预算有限 |
| **Qwen-VL-Plus** | 阿里云 | ¥1.5/千tokens | 高性价比，视频支持 | 生产环境 |
| **Claude 3.5 Sonnet** | Anthropic | $3/百万tokens | 最强推理 | 复杂设计分析 |

## 🔑 获取API密钥

### 1. GLM-4V（智谱AI）

**步骤：**

1. 访问 [智谱AI开放平台](https://open.bigmodel.cn/)
2. 注册/登录账号
3. 进入"API密钥"页面
4. 点击"创建API密钥"
5. 复制生成的API密钥（格式：`xxxxxxxxxxxxx.xxxxxxxxxxxx`）

**配置：**

```bash
# 编辑 .env 文件
GLM_API_KEY=你的GLM_API密钥
GLM_MODEL=glm-4v-flash
```

**官方文档：** https://open.bigmodel.cn/dev/api

---

### 2. Qwen-VL（阿里云通义千问）

**步骤：**

1. 访问 [阿里云百炼平台](https://bailian.console.aliyun.com/)
2. 开通服务（需要实名认证）
3. 创建API-KEY
4. 复制API密钥（格式：`sk-xxxxxxxxxxxxxxxxx`）

**配置：**

```bash
# 编辑 .env 文件
QWEN_API_KEY=你的Qwen_API密钥
QWEN_MODEL=qwen-vl-plus
```

**官方文档：** https://help.aliyun.com/zh/model-studio/vision

---

### 3. Claude Vision（Anthropic）

**步骤：**

1. 访问 [Anthropic Console](https://console.anthropic.com/)
2. 注册/登录账号
3. 进入"API Keys"页面
4. 创建新的API密钥
5. 复制密钥（格式：`sk-ant-xxxxxxxxxxxxxxxxx`）

**配置：**

```bash
# 编辑 .env 文件
ANTHROPIC_API_KEY=你的Claude_API密钥
CLAUDE_MODEL=claude-3-5-sonnet-20241022
```

**官方文档：** https://docs.anthropic.com/claude/docs/vision

---

## ⚙️ 配置后端

### 1. 编辑环境变量文件

```bash
cd /Users/qiupengchao/lab/shuqianApp/backend
nano .env
```

### 2. 填入API密钥

```bash
# GLM配置（推荐，免费）
GLM_API_KEY=你的GLM密钥

# Qwen配置（可选）
QWEN_API_KEY=你的Qwen密钥

# Claude配置（可选）
ANTHROPIC_API_KEY=你的Claude密钥

# 默认模型选择
DEFAULT_VISION_MODEL=glm
```

### 3. 重启后端

```bash
# 停止旧进程
lsof -ti:8000 | xargs kill -9 2>/dev/null

# 启动新后端
cd /Users/qiupengchao/lab/shuqianApp/backend
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload > /tmp/uvicorn.log 2>&1 &
```

---

## 🎯 使用方式

### 方式1：默认模型（推荐）

不指定模型参数，使用配置文件中的默认模型（GLM）：

```bash
curl -X POST http://localhost:8000/api/analyze-reference \
  -F "images=@photo1.jpg" \
  -F "images=@photo2.jpg"
```

### 方式2：指定模型

在请求中添加`model`参数：

```bash
# 使用GLM（免费）
curl -X POST http://localhost:8000/api/analyze-reference \
  -F "model=glm" \
  -F "images=@photo1.jpg"

# 使用Qwen
curl -X POST http://localhost:8000/api/analyze-reference \
  -F "model=qwen" \
  -F "images=@photo1.jpg"

# 使用Claude
curl -X POST http://localhost:8000/api/analyze-reference \
  -F "model=claude" \
  -F "images=@photo1.jpg"
```

### 方式3：查看可用模型

```bash
curl http://localhost:8000/api/models
```

返回示例：

```json
{
  "models": [
    {
      "id": "glm",
      "name": "GLM-4V-Flash",
      "provider": "智谱AI",
      "description": "免费多模态视觉模型，中文优化",
      "pricing": "免费",
      "features": ["完全免费", "中文优化", "多模态理解"],
      "is_default": true
    },
    {
      "id": "qwen",
      "name": "Qwen-VL-Plus",
      "provider": "阿里云",
      "description": "高性价比视觉语言模型",
      "pricing": "¥1.5/千tokens",
      "features": ["高性价比", "视频理解", "中文优化"],
      "is_default": false
    },
    {
      "id": "claude",
      "name": "Claude 3.5 Sonnet",
      "provider": "Anthropic",
      "description": "业界领先的视觉理解模型",
      "pricing": "$3/百万tokens",
      "features": ["最强推理", "设计分析", "英文优化"],
      "is_default": false
    }
  ],
  "default_model": "glm",
  "count": 3
}
```

---

## 🔍 验证配置

### 1. 检查后端日志

```bash
tail -f /tmp/uvicorn.log
```

### 2. 测试健康检查

```bash
curl http://localhost:8000/api/health
```

### 3. 测试图片分析

```bash
# 使用默认模型（GLM）
curl -X POST http://localhost:8000/api/analyze-reference \
  -F "images=@/path/to/test/image.jpg"

# 应该在日志中看到：
# 🤖 [GLM] Analyzing 1 images with glm-4v-flash
```

---

## 💡 最佳实践

### 开发环境

```bash
# 使用GLM（免费）
DEFAULT_VISION_MODEL=glm
```

### 生产环境

```bash
# 根据需求选择：
# - 预算敏感：GLM（免费）或 Qwen-VL-Plus（便宜）
# - 质量优先：Claude 3.5 Sonnet
DEFAULT_VISION_MODEL=qwen
```

### 混合使用

在应用中根据任务类型动态选择模型：

```python
# 简单任务使用GLM（免费）
model = "glm"

# 复杂设计分析使用Claude
if task_complexity > 8:
    model = "claude"

# 一般任务使用Qwen
else:
    model = "qwen"
```

---

## 🐛 故障排查

### 问题1：API密钥无效

**错误信息：** `401 Unauthorized` 或 `403 Forbidden`

**解决方法：**
1. 检查API密钥是否正确复制
2. 确认API密钥是否已激活
3. 检查账户余额是否充足（Qwen和Claude）

### 问题2：模型不支持

**错误信息：** `不支持的模型: xxx`

**解决方法：**
1. 确认模型名称：glm, qwen, claude（区分大小写）
2. 查看可用模型：`curl http://localhost:8000/api/models`

### 问题3：响应超时

**错误信息：** `Request timeout`

**解决方法：**
1. 检查网络连接
2. 查看API服务状态
3. 增加超时时间（在代码中配置）

### 问题4：解析失败

**错误信息：** `Failed to parse JSON`

**解决方法：**
1. 检查模型返回格式是否正确
2. 查看后端日志：`tail -f /tmp/uvicorn.log`
3. 某些模型可能返回非JSON格式，需要调整提示词

---

## 📞 获取帮助

- **GLM支持：** https://open.bigmodel.cn/
- **Qwen支持：** https://help.aliyun.com/zh/model-studio
- **Claude支持：** https://support.anthropic.com/

---

## 🔄 更新历史

- **2025-01-14**: 初始版本，支持GLM、Qwen、Claude三模型
- **默认模型**: GLM-4V-Flash（免费）
