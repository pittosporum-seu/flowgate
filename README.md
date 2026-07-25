# FlowGate

跨平台智能 VPN 客户端，基于 Flutter + sing-box。

## 特性 (规划中)

- 跨平台: Android / Windows
- 多协议: VMess / VLESS / Trojan / Shadowsocks / SOCKS
- 智能路由: 按服务自适应选择直连/代理
- AI 助手: 诊断网络问题，推荐路由策略
- 订阅管理: 自动更新节点订阅

## 项目状态

当前处于 **v0.0.1 基建阶段**，正在搭建 Flutter 骨架 UI。

## 目录结构

```
flowgate/
├── archive/          # 旧版代码归档 (仅供参考)
├── app/              # Flutter 主工程
├── docs/design/      # 模块设计文档
└── README.md
```

## 技术栈

| 层 | 技术 |
|----|------|
| UI | Flutter 3.x + Material Design 3 |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 本地存储 | Hive |
| 代理核心 | sing-box (libbox FFI) |
| AI | OpenAI / Anthropic / Gemini API |

## 开发工作流

- 分支: `main` -> `develop` -> `feat/x.y-description`
- 每个 Story 一个 feat 分支 + PR
- 每个 Epic 完成后打 tag

## License

TBD
