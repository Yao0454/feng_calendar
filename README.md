# 枫枫子的备忘录

从文字、截图、文件中自动提取日程和待办事项的跨平台 App，支持云同步、AI 对话规划、用户画像、个性化推荐（arXiv / GitHub / CSDN / StackOverflow）和学术日报。

## 功能

### 核心

- **智能提取**：文字 / 截图 / PDF / TXT 一键提取日程和待办，AI 回复自然语言确认
- **云同步**：账号登录后数据实时同步，多设备共享同一份日历
- **编辑 & 管理**：点击卡片编辑，右滑置顶，左滑删除；置顶条目显示红色边框
- **iOS 文件导入**：从其他 App 「打开方式」直接导入文件一键提取

### AI 对话

- **聊天规划**：对话式规划日程，支持草稿预览和一键导入；发送内容和回复均支持 Markdown 渲染
- **对话气泡**：两个聊天页均采用消息气泡样式（`reverse: true`），最新消息始终在底部

### 推荐 & 日报

- **个性化推荐**：基于用户画像聚合 arXiv / GitHub / HuggingFace / CSDN / StackOverflow 内容
- **论文阅读**：点击 arXiv 卡片「阅读论文」直接在 App 内渲染 PDF，无需跳转浏览器
- **arXiv 日报**：按领域偏好自动生成学术摘要日报

### 体验

- **浮动气泡导航栏**：毛玻璃效果，圆角悬浮，支持 `extendBody`
- **可拖拽 AI 按钮**：可吸附边缘隐藏，不遮挡操作区域
- **深色模式**：跟随系统，Material 3 动态配色
- **多端支持**：iOS / macOS / Android / Windows，GitHub Actions 自动构建

## 技术栈

| 层 | 技术 |
| --- | --- |
| 前端 | Flutter 3.38，Material 3，Provider |
| 本地存储 | sqflite，shared_preferences |
| HTTP | dio（30s 连接超时，180s 响应超时）|
| Markdown | flutter_markdown_plus |
| PDF 阅读 | pdfx |
| 后端 | FastAPI + Ollama（自建服务器）|
| AI 模型 | qwen3-vl:30b |
| 认证 | Session-based（bcrypt，30 天有效期）|
| 云存储 | 服务端 SQLite（按用户隔离）|

## 目录结构

```text
lib/
├── main.dart
├── models/models.dart
├── providers/app_provider.dart
├── services/
│   ├── api_service.dart          # HTTP 请求 + 统一错误处理
│   ├── auth_service.dart         # 登录/注册/Session 持久化
│   └── storage_service.dart      # SQLite 本地缓存
├── screens/
│   ├── home_screen.dart          # 自适应布局 + 浮动导航栏
│   ├── auth_screen.dart          # 登录/注册页
│   ├── input_screen.dart         # 提取页（含 AI 聊天模式）
│   ├── items_screen.dart         # 日程 & 待办列表
│   ├── chat_planning_screen.dart # AI 规划聊天
│   ├── recommendations_screen.dart
│   ├── daily_report_screen.dart
│   ├── paper_reader_screen.dart  # arXiv PDF 阅读器
│   └── settings_screen.dart
└── widgets/
    ├── floating_chat_button.dart  # 可拖拽悬浮按钮
    ├── event_card.dart
    ├── todo_card.dart
    └── edit_sheet.dart            # 编辑底部面板
```

## 后端 API

### 认证

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/auth/register` | 注册，body: `{username, password}` |
| POST | `/auth/login` | 登录，返回 `session_id` |
| GET | `/auth/me` | 当前用户信息 |
| POST | `/auth/logout` | 退出登录 |

### 日程提取

```http
POST /extract
Authorization: Bearer <session_id>
```

请求字段（三选一）：`text` / `image_base64` / `file_base64`，可附加 `current_date`（用于解析"明天"、"下周三"等相对日期）。

响应额外返回 `message` 字段，包含 AI 生成的自然语言确认。

### 日程 & 待办 CRUD

```http
GET/POST        /items
POST/PUT/DELETE /items/events/{id}
PATCH           /items/events/{id}/pin
POST/PUT/DELETE /items/todos/{id}
PATCH           /items/todos/{id}/done
PATCH           /items/todos/{id}/pin
```

### AI 聊天规划

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/chat/start` | 开始规划会话 |
| POST | `/chat/message` | 发送消息 |
| POST | `/chat/draft` | 生成规划草稿 |
| POST | `/chat/confirm/{id}` | 确认 / 取消草稿 |
| GET | `/chat/history/{session_id}` | 获取历史消息 |

### 推荐、日报 & 论文

```http
GET  /recommendations/feed
POST /recommendations/{id}/read
POST /recommendations/{id}/save
GET  /arxiv/preference
POST /arxiv/preference
POST /arxiv/report/generate
GET  /arxiv/report/today
GET  /arxiv/paper/{arxiv_id}/markdown   # PDF → Markdown（带缓存）
```

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行
flutter run -d macos
flutter run -d <iOS 设备 UDID>

# 打包
flutter build macos --release
flutter build ipa --release --export-method development
flutter build apk --release --split-per-abi
```

## 配置

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| 服务器地址 | `http://101.37.80.57:5522` | 后端地址，可在设置页修改 |
| 连接超时 | 30 秒 | |
| 响应超时 | 180 秒 | AI 推理较慢时不超时 |

## CI / CD

推送到 `main` 自动触发三平台构建（`.github/workflows/build.yml`）：

| 平台 | Runner | 产物 |
| --- | --- | --- |
| Android | ubuntu-latest | `app-release-arm64-v8a.apk` |
| Windows | windows-latest | `枫枫子的备忘录-Setup.exe`（Inno Setup） |
| macOS | macos-latest | `枫枫子的备忘录.dmg` |

推送 `v*` tag 后自动创建 GitHub Release 并附上三个安装包。

---

## 待实现

### iOS 主屏幕小组件（WidgetKit）

Flutter 侧 `home_widget` 桥接代码已写好（见 `AppProvider._updateWidget()`），原生侧待完成：

- [ ] Xcode → File → New → Target → Widget Extension（Product Name: `ScheduleWidget`）
- [ ] Runner + ScheduleWidget 两个 Target 均添加 App Group `group.com.example.fengCalendar`
- [ ] 替换自动生成的 `ScheduleWidget.swift`（见 `ios/ScheduleWidget/ScheduleWidget.swift`）
- [ ] Runner Build Settings → Code Signing Entitlements → `Runner/Runner.entitlements`
- [ ] 主屏幕长按 → 添加小组件 → 验证数据更新
