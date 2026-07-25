# FlowGate 旧版代码归档说明

本目录保存 FlowGate 项目重构前的历史源码，仅供参考，不再维护。

## android-v200/

- **来源**: `C:\Users\13736\Documents\Codex\flowgate-build-v200`
- **版本**: FlowGate 2.0.0 (versionCode 200)
- **基础**: fork 自 [2dust/v2rayNG](https://github.com/2dust/v2rayNG)
- **技术栈**: Kotlin, Android Gradle, Xray Core (libv2ray.aar)
- **包名**: `com.njl.flowgate`
- **功能状态**:
  - VPN 模式 (VpnService) 基本可用
  - 路由模式: Smart CN / Global / Block CN / Custom
  - 自适应服务探测 (OpenAI/Google/DeepSeek 等)
  - AI 路由助手 (OpenAI/Anthropic/Gemini 协议)
  - 订阅管理 (vmess/vless/trojan/ss)
- **已知问题**:
  - God Object: FlowGateModeManager (574行), FlowAdaptiveServiceManager (602行)
  - 接口空转: RoutingEngine/ServiceProbeEngine/AdaptiveRouteResolver 定义但未实现
  - 无依赖注入，全部 object 单例互调
  - 状态管理散落在 MMKV 直接读写中
  - 自适应探测在部分设备上不稳定
  - AI 模块响应慢，无流式输出

## windows-trojan/

- **来源**: `C:\Users\13736\Documents\Codex\2026-06-08\windows-trojan-vpn-exe`
- **版本**: TrojanSubVPN 1.0
- **技术栈**: PowerShell + sing-box 1.13.13 + PyInstaller 打包
- **功能状态**:
  - 单 exe 启动器，释放 payload 到 %LOCALAPPDATA%
  - 支持 trojan:// 订阅 (base64/明文)
  - 系统代理模式 (127.0.0.1:10808)
  - 菜单式交互 (启动/停止/刷新订阅/选节点)
- **已知问题**:
  - 仅支持 trojan 协议
  - 非 TUN 模式，部分应用不走代理
  - 无 GUI，纯命令行

## 其他相关位置 (未归档)

| 路径 | 说明 |
|------|------|
| `C:\Users\13736\OneDrive\Documents\MyFiles\code\FlowGate` | v2rayNG 上游 clone + git submodules |
| `C:\Users\13736\Documents\Codex\flowgate-build-v12-*` ~ `v140` | 历史构建版本 (v1.2~v1.4) |
| `C:\Users\13736\Documents\Codex\FlowGateReleaseBuild` | v1.1 release 构建 |
| `C:\Users\13736\Documents\Codex\FlowGateBuild_v130/v131` | v1.3.0/v1.3.1 构建 |
