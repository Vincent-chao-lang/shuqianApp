# BookmarkDesigner 项目结构总结

## 📂 项目目录结构

```
BookmarkDesigner/
├── iOS前端
│   ├── BookmarkDesigner.xcodeproj/      # Xcode项目文件
│   └── BookmarkDesigner/
│       ├── Models/                        # 数据模型
│       │   ├── APIResponseModels.swift    # API响应模型
│       │   ├── ColorScheme.swift          # 配色方案
│       │   ├── DesignColor.swift          # 设计颜色
│       │   ├── DesignState.swift         # 全局状态管理
│       │   └── MoodOptions.swift          # 情绪选项
│       │
│       ├── Services/                      # 服务层
│       │   └── NetworkManager.swift       # 网络请求管理
│       │
│       ├── Views/                         # 视图层
│       │   ├── Components/                # 可复用组件
│       │   │   ├── ImagePicker.swift      # 图片选择器
│       │   │   ├── ProgressBar.swift      # 进度条
│       │   │   └── TextColorPickerSheet.swift
│       │   │
│       │   ├── WelcomeView.swift          # 欢迎页
│       │   ├── UploadReferenceView.swift  # 上传参考图
│       │   ├── AIAnalysisResultView.swift # AI分析结果页
│       │   ├── ManualConfigView.swift    # 手动配置页
│       │   └── ResultView.swift          # 结果展示页
│       │
│       ├── Extensions/                    # 扩展
│       │   └── ColorExtensions.swift      # 颜色扩展
│       │
│       ├── Assets.xcassets/               # 资源文件
│       └── Info.plist                     # 配置文件
│
└── shuqianApp/backend/                    # Python后端
    ├── app/
    │   ├── __init__.py
    │   ├── main.py                        # FastAPI应用入口
    │   │
    │   ├── api/                           # API路由
    │   │   ├── __init__.py
    │   │   └── routes.py                  # 所有API端点
    │   │
    │   ├── core/                          # 核心配置
    │   │   ├── __init__.py
    │   │   └── config.py                  # 配置管理
    │   │
    │   ├── models/                        # 数据模型
    │   │   ├── __init__.py
    │   │   └── schemas.py                  # Pydantic模型
    │   │
    │   ├── services/                      # 业务服务
    │   │   ├── __init__.py
    │   │   ├── bookmark_generator.py      # 书签生成器
    │   │   ├── image_generator.py         # 文生图服务
    │   │   ├── vision_adapter.py          # AI分析适配器
    │   │   ├── claude_analyzer.py         # Claude分析器
    │   │   └── llm_analyzer.py            # LLM分析器
    │   │
    │   └── utils/                         # 工具函数
    │       ├── __init__.py
    │       └── helpers.py                  # 辅助函数
    │
    ├── downloads/                         # 生成的文件下载目录
    ├── logs/                              # 日志文件
    ├── uploads/                           # 上传的临时文件
    ├── tests/                             # 测试文件
    │   └── test_api.py
    ├── requirements.txt                    # Python依赖
    ├── run.py                             # 开发服务器启动脚本
    └── .env                               # 环境变量（需手动创建）
```

---

## 🔌 API端点总览

### 核心接口

| 端点 | 方法 | 功能 | 认证 |
|------|------|------|------|
| `/health` | GET | 健康检查 | ❌ |
| `/api/analyze` | POST | AI图片分析 | ❌ |
| `/api/generate-preview` | POST | 生成预览图 | ❌ |
| `/api/text-to-image` | POST | 文生图生成 | ❌ |
| `/api/generate-final` | POST | 生成最终书签 | ❌ |
| `/downloads/*` | GET | 下载生成的文件 | ❌ |

---

## 🔄 数据流程

### 1. AI路径流程
```
用户上传图片
  → iOS: UIImage → Base64
  → POST /api/analyze
  → 后端: GLM-4-Vision分析
  → 返回: 配色方案 + 描述
  → 用户确认并输入文字
  → POST /api/text-to-image (文生图)
  → POST /api/generate-final (添加文字)
  → 返回: PNG + PDF
```

### 2. 手动配置流程
```
用户上传图片
  → POST /api/generate-final
  → 后端: PIL处理
  → 返回: PNG + PDF
```

---

## 🗄️ 数据库设计

**当前版本**: 无数据库（无状态API）

**使用的存储**:
- 内存缓存（图片、生成结果）
- 文件系统（`/uploads`, `/downloads`）
- 定时清理任务（APScheduler）

**未来可扩展**:
- PostgreSQL存储用户设计历史
- Redis缓存热点数据
- OSS对象存储图片

---

## 🔐 环境变量配置

### 后端 (.env)
```bash
# AI服务密钥
ZHIPU_AI_API_KEY=your_key_here
ANTHROPIC_API_KEY=your_key_here

# CORS配置
CORS_ORIGINS=["*"]

# 服务器配置
HOST=0.0.0.0
PORT=8000

# 日志级别
LOG_LEVEL=INFO
```

### iOS客户端
- `baseURL`: API服务器地址
- 权限配置在Info.plist中

---

## 📦 依赖版本

### iOS
- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- SwiftUI

### 后端
- Python 3.10+
- FastAPI 0.115.0
- Uvicorn 0.32.0
- Pillow 11.0.0
- Pydantic 2.9.2
- OpenCV 4.10.0
- Loguru 0.7.2

---

## 🧪 测试

### 后端测试
```bash
cd backend
pytest tests/ -v
```

### 手动测试API
```bash
# 健康检查
curl http://localhost:8000/health

# 图片分析
curl -X POST http://localhost:8000/api/analyze \
  -F "images=@test.jpg"

# 文生图
curl -X POST http://localhost:8000/api/text-to-image \
  -H "Content-Type: application/json" \
  -d '{"prompt": "美丽的风景", "mood": "现代时尚"}'
```

---

## 📱 构建与发布

### iOS App
1. 在Xcode中选择任意iOS Simulator
2. Product → Archive
3. Distribute App
4. 选择发布方式：

**开发测试**:
- Ad Hoc Provisioning
- 内部分发

**App Store发布**:
- App Store Distribution
- 提交审核

### 后端部署
详见 `DEPLOYMENT_GUIDE.md`

---

## 🎯 MVP功能清单

### ✅ 已完成
- [x] 图片上传（相册/相机）
- [x] AI智能分析
- [x] 文生图背景生成
- [x] 手动配置模式
- [x] 文字编辑（字体、颜色、大小、对齐、横竖排）
- [x] 文字精确定位（像素级）
- [x] 实时预览
- [x] 竖排文字支持
- [x] 多格式导出（PNG/PDF）
- [x] 保存到相册
- [x] 系统分享
- [x] 权限管理

### 🚀 未来增强
- [ ] 用户登录/注册
- [ ] 设计历史保存
- [ ] 模板库
- [ ] 社区分享
- [ ] iPad适配
- [ ] 批量生成
- [ ] 视频书签

---

## 📞 联系方式

- **GitHub**: [项目仓库地址]
- **文档**: `/Users/qiupengchao/lab/shuqianApp/DEPLOYMENT_GUIDE.md`

---

**项目状态**: MVP已完成 ✅
**最后更新**: 2026-01-16
