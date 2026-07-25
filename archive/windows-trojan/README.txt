TrojanSubVPN 使用说明
====================

文件:
- TrojanSubVPN.exe: 单文件启动器
- TrojanSubVPN_SHA256.txt: 文件校验信息

怎么用:
1. 双击 TrojanSubVPN.exe。
2. 第一次运行会把内置文件释放到 %LOCALAPPDATA%\TrojanSubVPN。
3. 在菜单里选 4 输入订阅链接，或选 3 刷新已有订阅。
4. 选 5 选择节点。
5. 选 1 启动代理。
6. 不用时选 2 停止代理，它会恢复启动前的 Windows 代理设置。

支持范围:
- 支持包含 trojan:// 链接的订阅。
- 支持常见 base64 链接订阅。
- 支持 Trojan TCP/TLS 节点和基础 WebSocket 参数。

注意:
- 没有内置任何节点、账号或订阅地址。
- 当前是 Windows 系统代理模式，本地端口是 127.0.0.1:10808。
- 不是 TUN 虚拟网卡全局 VPN 模式；不读取系统代理的程序可能不会自动走代理。

开源组件:
- sing-box 1.13.13 windows-amd64
- https://github.com/SagerNet/sing-box
