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

---

## 附录 C — 新手排障速查（两条路 + 爆音/延迟）

> 写给第一次折腾音频链的玩家。核心心法一句话：
> **电平表就是声卡的体温计——学会看它，80% 的音频问题可以自诊。**
>
> 音频问题从不报错，它只制造"缺失"（无声）。所以排障的本质是
> **把"无声"变成"能看见的线索"**：让信号流经的每一段都有可视化证明。

### C.1 先分清两条路

| | 路线一：Voicemeeter 桥接 | 路线二：THR10II 直连（ASIO THRII） |
|---|---|---|
| 状态 | 本趟实测**失败**，仅作记录 | **推荐**，实测能通 |
| 适用 | "只有 64 位 ASIO"的声卡（如THR10ii）的绕行方案 | 本文档主角（THR10II / THR-II 系列） |
| 排障要点 | 见 C.2 | 见 C.3 |

### C.2 路线一：Voicemeeter（失败记录 + 排障要点）

**失败记录（THR10II 环境实测）**：走 VM 桥接时始终无声 / 调音信号乱跳，
按路由、回环、通道逐项排查均未打通，最终放弃并转直连（C.3）后一切正常。
对 THR10II 不再推荐此路线；保留本节是因为网上很多教程让你走这条路，
且对"只有 64 位 ASIO"的声卡它仍是官方认可的绕行方案。

**排障要点**（如果仍要排查 VM 链路）：

RS 的音频能通的条件：下面所有条件必须**全部**为真，任何一个出错结果都只是"无声"、零报错。

```
① 声卡/音箱硬件开关
   ├─ 音箱电源、音量旋钮开大
   ├─ 音箱音源(SOURCE)切到 USB 档（最容易被忽略的一步！）
   └─ 没插着耳机独占输出

② 驱动/程序层
   ├─ Voicemeeter（如果用桥接）确实在运行（托盘有小图标）
   └─ 游戏/音频程序是"先开 Voicemeeter 后启动"的顺序

③ Voicemeeter 路由（桥接方案）
   ├─ 右上角 HARDWARE OUT：A1 按钮选到了 THR10II
   ├─ 信号进来的那条输入条：路由区有 A1/B1 灯亮着（绿）
   ├─ 该条没有静音(M)、推子不在 0
   └─ 看到电平表在跳动（有信号进来）

④ 系统层面
   ├─ Windows 默认播放设备：选 VoiceMeeter Input（桥接时）
   │   或 Yamaha THR10II（直连时）
   └─ 音量合成器里对应设备没被静音/拉低

⑤ 游戏内
   ├─ 音乐/音效音量没被拉低
   └─ 输入设备选的是正确的模式（直连后 RTC/麦克风均可）
```

**排障观察技巧**：哪一段的电平是"死的"，问题就在那一段到上一段之间。

### C.3 路线二：THR10II 直连（推荐，实测能通）

**能通的链路**：

```
吉他 → THR10II（USB）→ 32 位 ASIO DLL（右声道 = 干声）→ RS ASIO → 游戏
游戏 → RS ASIO → 32 位 ASIO DLL → THR10II → 音箱出声
```

**新手动作清单**（详细步骤见正文第 3 节）：
1. 64 位驱动保持不动，**不装 v1 全家桶**
2. 管理员权限放回两个 DLL 到 `SysWOW64`（见正文）
3. `RS_ASIO.ini` / `Rocksmith.ini` 按附录 A / B 配置
4. **不用开 Voicemeeter**
5. 启动游戏

**中间遇到的真问题**（直白版）：

| 问题 | 是什么 | 怎么办 |
|---|---|---|
| 爆音 / 声音像"增益爆了"（失真） | 多半是 **THR 音箱上某个旋钮拧大了**——master / guitar volume / gain 里某处。具体是哪个钮因人而异，不用纠结 | **往小拧**：音量类旋钮拧小、gain 保持低，直到声音干净。拧小后仍爆，才轮到缓冲侧（下表） |
| 跟手感延迟 | 缓冲太大 / 链路长 | 下表往小调 |
| 音符卡不上动画 | 游戏的"可视化延迟校准"没校准 | 进游戏校准界面，跟着**听到的**节拍点击，多测几次 |

**爆音 / 延迟对照表：**

| 现象 | 动作 | 方向 |
|---|---|---|
| 爆音 | `RS_ASIO.ini` → `[Asio]` → `CustomBufferSize`：128→192→256（必须 32 的倍数） | ↑ |
| 还爆 | `Rocksmith.ini` → `[Audio]` → `LatencyBuffer`：1→2 | ↑ |
| 弹着发钝/发"闷" | `CustomBufferSize` 往 96 试（THR 上实测 96 会开始爆，谨慎） | ↓ |

**口诀：压到刚好不爆的最小值，然后停手。**
改完配置必须**重启游戏**才生效（RS ASIO 在启动时读配置）。

### C.4 隐藏元凶清单（两条路共用）

| 元凶 | 症状 |
|---|---|
| 游戏/软件自己重写了配置文件 | 参数昨天还是对的今天变了 → 看文件修改时间 |
| 残留的空壳注册 / 死设备 | 设备列表里有个设备但点不开 → 检查驱动注册指向的文件存在性 |
| 两个程序同时独占声卡 | 一个占着设备，另一个无声/报"设备正在使用"(0xC00D4E85) → 先关掉占用的 |
| 采样率不匹配 | 全部设 48kHz（RS ASIO 固定请求 48k） |
| Windows 默认设备被改成"死设备" | 没有程序运行它还占着默认 → 系统音全哑 → 检查喇叭图标 |
