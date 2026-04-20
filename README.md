# 枫枫子的备忘录

从文字、截图、文件中自动提取日程和待办事项的跨平台 App。

## 功能

- **文字提取**：粘贴任意中英文文字，AI 自动识别日程与待办
- **图片提取**：选择截图或照片，OCR + AI 解析
- **文件提取**：上传 PDF / TXT / MD，批量提取
- **本地持久化**：SQLite 存储所有历史记录
- **自适应布局**：macOS 侧边栏 / iOS 底部导航栏
- **深色模式**：跟随系统自动切换

## 技术栈

| 层 | 技术 |
| --- | --- |
| 前端 | Flutter 3.x，Material 3，Provider |
| 本地存储 | sqflite，shared_preferences |
| HTTP | dio（连接超时 30s，响应超时 180s）|
| 后端 | FastAPI + Ollama（本地服务器）|
| AI 模型 | qwen2.5:72b（可在设置页更换）|

## 目录结构

```text
lib/
├── main.dart                  # 入口，Provider 注入，主题配置
├── models/models.dart         # ScheduleEvent, Todo, ExtractionResult
├── providers/app_provider.dart # 全局状态（ChangeNotifier）
├── services/
│   ├── api_service.dart       # HTTP 请求封装
│   └── storage_service.dart   # SQLite CRUD
├── screens/
│   ├── home_screen.dart       # 自适应 Scaffold
│   ├── input_screen.dart      # 文字/图片/文件输入
│   ├── items_screen.dart      # 日程+待办列表
│   └── settings_screen.dart   # 服务器配置
└── widgets/
    ├── event_card.dart        # 日程卡片
    ├── todo_card.dart         # 待办卡片
    └── empty_state.dart       # 空状态占位
```

## 后端 API

### POST `/extract`

```json
// 请求（三选一）
{
  "text": "明天下午 3 点在 11-100 开组会",
  "image_base64": "<base64>",
  "file_base64": "<base64>",
  "file_type": "pdf"
}

// 响应
{
  "events": [
    { "title": "...", "date": "2026-04-26", "time": "15:00", "location": "...", "notes": "..." }
  ],
  "todos": [
    { "title": "...", "deadline": "2026-05-10", "priority": "high", "notes": "..." }
  ]
}
```

### GET `/health`

返回 `{"status": "ok"}`，用于设置页连接检测。

## 快速开始

```bash
# 安装依赖
flutter pub get

# 生成图标（需要 assets/icon.png）
dart run flutter_launcher_icons

# 运行
flutter run -d macos
flutter run -d <iOS设备UDID>

# 打包
flutter build macos --release
flutter build ipa --release          # 需要 Apple Developer 证书
```

## 配置

在 App 设置页修改，或直接编辑 `lib/services/api_service.dart`：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| 服务器地址 | `http://101.37.80.57:5522` | 后端 FastAPI 地址 |
| 模型名 | `qwen2.5:72b` | Ollama 模型 |
| 连接超时 | 30 秒 | dio connectTimeout |
| 响应超时 | 180 秒 | dio receiveTimeout |

---

## 待实现 TODO

### iOS/macOS 主屏幕小组件（WidgetKit）

Flutter 侧桥接代码已通过 `home_widget` 包准备好，但 WidgetKit 原生侧尚未实现。

#### Flutter 侧（已写好，提取完成后调用）

```dart
import 'package:home_widget/home_widget.dart';

// 在 AppProvider._extract() 成功后调用
await HomeWidget.saveWidgetData('events_json', jsonEncode(todayEvents));
await HomeWidget.saveWidgetData('todos_json', jsonEncode(pendingTodos));
await HomeWidget.updateWidget(
  iOSName: 'ScheduleWidget',
);
```

#### 原生侧待办清单

- [ ] **Xcode：添加 Widget Extension Target**
  - File → New → Target → Widget Extension
  - Product Name: `ScheduleWidget`
  - 取消勾选 "Include Configuration App Intent"

- [ ] **配置 App Group**（Flutter ↔ WidgetKit 共享数据）
  - Runner target → Signing & Capabilities → + App Groups
  - 添加 `group.com.example.fengCalendar`
  - ScheduleWidget target 同样添加该 App Group
  - Flutter 侧调用 `HomeWidget.setAppGroupId('group.com.example.fengCalendar')`

- [ ] **实现 `ScheduleWidget.swift`**（SwiftUI）

  ```swift
  import WidgetKit
  import SwiftUI

  struct ScheduleEntry: TimelineEntry {
      let date: Date
      let events: [[String: String]]
      let todos: [[String: String]]
  }

  struct ScheduleProvider: TimelineProvider {
      func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
          completion(makeEntry())
      }
      func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
          let entry = makeEntry()
          completion(Timeline(entries: [entry], policy: .atEnd))
      }
      func placeholder(in context: Context) -> ScheduleEntry { makeEntry() }

      private func makeEntry() -> ScheduleEntry {
          let defaults = UserDefaults(suiteName: "group.com.example.fengCalendar")
          let eventsJson = defaults?.string(forKey: "events_json") ?? "[]"
          let todosJson  = defaults?.string(forKey: "todos_json")  ?? "[]"
          let events = (try? JSONSerialization.jsonObject(with: Data(eventsJson.utf8))) as? [[String: String]] ?? []
          let todos  = (try? JSONSerialization.jsonObject(with: Data(todosJson.utf8)))  as? [[String: String]] ?? []
          return ScheduleEntry(date: .now, events: events, todos: todos)
      }
  }

  struct ScheduleWidgetView: View {
      let entry: ScheduleEntry
      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              Text("今日日程").font(.caption).foregroundStyle(.secondary)
              ForEach(entry.events.prefix(3), id: \.self) { e in
                  Label(e["title"] ?? "", systemImage: "calendar")
                      .font(.caption2).lineLimit(1)
              }
          }
          .padding()
      }
  }

  @main
  struct ScheduleWidget: Widget {
      var body: some WidgetConfiguration {
          StaticConfiguration(kind: "ScheduleWidget", provider: ScheduleProvider()) { entry in
              ScheduleWidgetView(entry: entry)
          }
          .configurationDisplayName("枫枫子的备忘录")
          .description("今日日程速览")
          .supportedFamilies([.systemSmall, .systemMedium])
      }
  }
  ```

- [ ] **macOS Widget Extension**（可选，步骤同 iOS，Target 选 macOS）

- [ ] **测试**：在模拟器主屏幕长按 → 添加小组件 → 验证数据更新
