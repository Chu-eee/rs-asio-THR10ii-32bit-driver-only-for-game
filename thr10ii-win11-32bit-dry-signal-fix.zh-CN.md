# THR10II + RS ASIO 在 Windows 11 上的解法：不降级系统驱动，恢复 32 位 ASIO

> 一套经过实测的"最小干预"方案（Windows 11 25H2 验证）：
> **保留当前的 64 位 Yamaha 驱动栈不动**，只恢复**用户态的 32 位 ASIO 组件**，
> 让 Rocksmith 直接走 `ASIO THRII`。
> 不需要 Voicemeeter、不需要忍受湿声输入、Cubase（64 位）不受影响、
> 不碰系统"内存完整性"（HVCI）开关。

---

## 1. 问题是什么

- RS ASIO 只认/只找 **32 位 ASIO 驱动**（Rocksmith 2014 是 32 位进程）。
- 现在 Yamaha 官方驱动（`Yamaha Driver2_5 THRII v2.0.0.0`，2024 年 WHQL）**只带 64 位 ASIO DLL**
  （`ThriiAsio_OnInterposer_x64.dll`）。解剖过 v2 安装包可以确认：**包里根本没有 32 位 ASIO 组件**。
- 装老版 **v1.0.0.0** 全家桶看似能解决，但有两个副作用：
  1. 它**整体替换驱动栈** → 64 位宿主程序（比如 Cubase）会失去声卡；
  2. 在 Windows 11 上它的老内核驱动会被**内存完整性（HVCI）**拦截
     （社区实测：必须关掉系统安全功能才能用）。

## 2. 核心洞察

32 位 ASIO 支持其实是一个**用户态 COM 组件**（`YamahaTHRIIAsio_OnInterposer.dll`），
游戏只需要**这一个文件**。内核/WDM 驱动完全可以继续用 v2.0.0.0。

也就是把两层拆开看：

| 层 | 是什么 | 我们的做法 |
|---|---|---|
| 内核/WDM 驱动（`YamahaTHRII.sys` v2.0.0.0） | 所有程序都在用（Windows、64 位 DAW） | **原封不动** |
| 32 位 ASIO DLL（用户态） | 只有 32 位 ASIO 客户端用（Rocksmith + RS ASIO） | **只补回这一个文件** |

## 3. 操作步骤

1. 保持当前 v2.0.0.0 驱动不动。**不要安装 v1 全家桶。**
2. 从 **v1.0.0.0 安装包**（`Yamaha Driver THRII v1.0.0.0 Installer.exe`，Yamaha 官网亦提供 zip 版）中提取：
   - `YamahaTHRIIAsio_OnInterposer.dll`（x86，约 266 KB）
   - `InterposerTHRIIBackend.dll`（x86，约 77 KB）
   - 7-Zip 可以直接解 NSIS 安装包：`7z x "Yamaha Driver THRII v1.0.0.0 Installer.exe"`
     （文件在 `Driver Archive\THRII\` 目录下）
3. 把这两个 DLL 复制到 `C:\Windows\SysWOW64\`（**需要管理员权限**）。
4. 32 位 ASIO 注册项（`HKLM\SOFTWARE\WOW6432Node\ASIO\ASIO THRII` →
   `HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\{4A1C1DA6-7749-41d5-A13f-aed70386c0f8}`）
   通常**已经存在**（v1 安装时留下的）。如果注册表是干净的，用 `regsvr32` 或手动导入
   指向 SysWOW64 DLL 的 CLSID/ASIO 键即可。
5. 配置（见附录）：`RS_ASIO.ini` → `Driver=ASIO THRII`，输入 `Channel=1`（右声道 = **干声**），
   `SoftwareMasterVolumePercent=200`；`Rocksmith.ini` → `ExclusiveMode=1`、`Win32UltraLowLatencyMode=1`。
6. **游戏使用此路径时不要开 Voicemeeter**——Voicemeeter 同时占用 THR 设备，
   正是 issue #519 里 "Failed to create ASIO buffers" 失败的真正原因。

## 4. 实测证据

- 在 Windows 11 25H2 + 驱动 v2.0.0.0 + v1 插桩 DLL 的组合下验证：RS ASIO 日志显示
  `Creating AsioSharedHost - dll: ...\SysWow64\YamahaTHRIIAsio_OnInterposer.dll`、
  通道正常枚举（`THRII (Left)` / `THRII (Right)`）、缓冲创建成功、数据流运行正常。
- 结论：**v1 的用户态 ASIO DLL 与 v2 内核驱动兼容**。
- 顺带平反 issue #519（"Yamaha THR10II ... Failed to create ASIO buffers"）：
  那次失败的根源是 Voicemeeter 和 RS ASIO 同时抢 THR 设备，
  **不是 v1/v2 不兼容**。

## 5. 通道图（对游戏体验至关重要）

THR-II 系列暴露的是立体声采集：**左声道 = 湿声（音箱模拟/效果音）**，**右声道 = 干声**。
Rocksmith 本身就是音箱模拟器，音高检测需要**干声** →
在 `[Asio.Input.1]` 里用 `Channel=1`，并用 `SoftwareMasterVolumePercent=200` 补增益
（干声信号很弱）。

## 6. 如何回滚

以管理员权限删除 `C:\Windows\SysWOW64\` 里的**两个文件**即可（上面那两个 DLL）。
因为驱动栈从没被碰过，没有其他需要恢复的东西。

---

## 附录 A — RS_ASIO.ini（实测可用的基线）

```ini
[Config]
EnableWasapiOutputs=0
EnableWasapiInputs=0
EnableAsio=1

[Asio]
BufferSizeMode=custom
CustomBufferSize=128

[Asio.Output]
Driver=ASIO THRII
BaseChannel=0
AltBaseChannel=
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=100
EnableRefCountHack=

[Asio.Input.0]
Driver=
Channel=0
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=100
EnableRefCountHack=

[Asio.Input.1]
Driver=ASIO THRII
Channel=1
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=200
EnableRefCountHack=

[Asio.Input.Mic]
Driver=ASIO THRII
Channel=1
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=200
EnableRefCountHack=
```

## 附录 B — Rocksmith.ini（相关行）

```ini
[Audio]
EnableMicrophone=1
ExclusiveMode=1
LatencyBuffer=1
Win32UltraLowLatencyMode=1
```

## 参考链接

- mdias/rs_asio issue [#210 – Yamaha THR10II Confirmed Working](https://github.com/mdias/rs_asio/issues/210)
  （内含 rvighne 的湿/干声道实测笔记）
- mdias/rs_asio issue [#519 – RS sees no sound output (THR10II)](https://github.com/mdias/rs_asio/issues/519)
- Yamaha ASIO Driver V1.0.0.0（32 位时代）/ V2.0.0.0（仅 64 位）官方下载页