# iOS 后端连接配置指南

## 1. 后端服务器配置

后端已配置好CORS，允许iOS客户端访问。

### 后端服务地址
- 本地开发: `http://localhost:8000`
- API路径: `http://localhost:8000/api`

### 已配置的API端点
| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/health` | GET | 健康检查 |
| `/api/analyze-reference` | POST | 分析参考图片 |
| `/api/generate-preview` | POST | 生成预览 |
| `/api/generate-final` | POST | 生成最终书签 |

---

## 2. iOS客户端配置

### 2.1 配置 App Transport Security（允许HTTP请求）

Xcode 16.4+ 不再使用 Info.plist 文件，需要在 Target Settings 中配置：

**步骤：**

1. 在 Xcode 中打开项目
2. 选择项目文件（BookmarkDesigner）
3. 选择 Target "BookmarkDesigner"
4. 进入 "Info" 标签页
5. 找到 "App Transport Security" 设置
6. 添加以下配置：

```
Key: App Transport Security
Type: Dictionary
  ├─ Key: Allow Arbitrary Loads
  │  Type: Boolean
  │  Value: YES
  │
  └─ Key: Exception Domains (可选，更安全)
     Type: Dictionary
     └─ Key: localhost
        Type: Dictionary
        ├─ Key: NSExceptionAllowsInsecureHTTPLoads
        │  Type: Boolean
        │  Value: YES
        │
        └─ Key: NSExceptionMinimumTLSVersion
           Type: String
           Value: TLSv1.0
```

**推荐方式（更安全）：**
只允许 localhost 使用 HTTP：

```
App Transport Security
  └─ Exception Domains
     └─ localhost
        ├─ NSExceptionAllowsInsecureHTTPLoads: YES
        └─ NSIncludesSubdomains: YES
```

---

### 2.2 验证配置

配置完成后，在iOS项目中添加测试代码：

```swift
// 在NetworkManager中添加健康检查方法
func checkHealth() async -> Bool {
    do {
        let _: [String: Any] = try await performRequest(
            endpoint: "/health",
            method: .GET
        )
        return true
    } catch {
        print("后端连接失败: \(error)")
        return false
    }
}
```

---

## 3. 测试连接

### 3.1 启动后端服务

```bash
cd /Users/qiupengchao/lab/shuqianApp/backend
python run.py
```

验证后端运行：
```bash
curl http://localhost:8000/api/health
```

### 3.2 运行iOS应用

1. 在Xcode中运行应用
2. 检查控制台是否有网络错误
3. 如果看到 "后端连接失败" 错误：
   - 检查后端是否运行
   - 检查ATS配置
   - 检查URL是否正确

---

## 4. API使用示例

### 测试预览生成

```swift
// 在某个View中调用
Task {
    let result = await networkManager.generatePreview(
        mood: "温暖治愈",
        complexity: 3,
        colors: ["#F5F5DC", "#8B7355"],
        layout: "left-right"
    )

    switch result {
    case .success(let preview):
        print("预览生成成功: \(preview.url)")
        // 使用 preview.image
    case .failure(let error):
        print("预览生成失败: \(error.message)")
    }
}
```

---

## 5. 常见问题

### Q1: Connection was interrupted
**原因**: ATS阻止了HTTP请求
**解决**: 按上述步骤配置ATS

### Q2: Connection refused
**原因**: 后端服务未运行
**解决**: 确保后端服务正在运行 `python run.py`

### Q3: CORS错误
**原因**: 后端CORS未配置
**解决**: 后端已配置 `ALLOW_LOCAL_DEV: True`，重启后端服务

### Q4: Cannot build because Info.plist missing
**说明**: Xcode 16.4+ 不再使用 Info.plist
**解决**: 在 Target Settings -> Info 中配置即可

---

## 6. 当前状态

- ✅ 后端CORS已配置（允许所有源）
- ✅ iOS NetworkManager已更新
- ⏳ 需要配置iOS ATS
- ⏳ 需要测试连接

---

## 7. 下一步

1. 在Xcode中配置ATS
2. 运行iOS应用测试连接
3. 如果成功，移除mock数据逻辑
4. 实现multipart图片上传
