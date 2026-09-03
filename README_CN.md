# THR10II 接 Rocksmith 复刻指南（新手向，按顺序做，约 15 分钟）/交给codex、claudecode、豆包电脑版、DSH……也可以让它帮你做

> 这份指南只讲"怎么做"，不聊原理。全流程就 **4 步**：
> **① 恢复 32 位驱动组件 → ② 放 3 个文件进游戏目录 → ③ 改两个 ini → ④ 启动验证**
>
> 如果中途看不懂某个词，先翻到最后的【小词典】再看回来。

---
## 大部分用到的东西
[rs-THR10ii-32bit-asio-fork-package](rs-THR10ii-32bit-asio-fork-package)

## 其他语言
[英语](README.md)

## 第 0 步：你需要准备的东西（全部免费）

| 需要 | 从哪来 | 干什么用 |
|---|---|---|
| 老版 Yamaha 驱动安装包 `Yamaha Driver THRII v1.0.0.0` | Yamaha 官网（或本仓库脚本自动下载） | 只取里面的 2 个小文件，不是安装它 |
| 7-Zip 解压软件 | [7-zip.org](https://www.7-zip.org) | 把上面的安装包"拆开"取文件 |
| RS ASIO 压缩包 `release-0.7.5.zip` | rs_asio 官方 GitHub Release 页面 | 里面的 3 个文件要放进游戏目录 |

> 电脑上已有 64 位 Yamaha 驱动（v2.0.0.0）就什么都不用动——**你的任务不是重装驱动，是"补一个文件"**。

---

## 第 1 步：恢复 32 位驱动组件（只需做一次，要管理员权限）

**这一步在干什么**：Rocksmith 是 32 位程序，它需要 32 位的声音驱动组件；新版 Yamaha 驱动没带这个组件，老版才有。我们只把老版里的那个组件"借"出来放进系统，**不安装老驱动本身**。

**两种做法，选一个：**

### 做法 A：用一键脚本（推荐）

1. 下载脚本 `restore_32bit_asio.cmd`
2. **右键 → 以管理员身份运行**
3. 它自动完成：下载老包装 → 拆包 → 放 2 个文件进 `C:\Windows\SysWOW64` → 写注册表
4. 最后显示 3 行 `[OK]` 就成功了（有 `[FAIL]` 就截图问我）

### 做法 B：手动（想看懂每个环节用这个）

1. 用 7-Zip 打开老版安装包（右键 → 7-Zip → 打开压缩包）
2. 进入文件夹 `Driver Archive\THRII\`，把这两个文件**解压出来**：
   - `YamahaTHRIIAsio_OnInterposer.dll`
   - `InterposerTHRIIBackend.dll`
3. 打开"此电脑" → `C:\Windows\SysWOW64`（**注意是 SysWOW64，不是 System32**）
4. 把上面两个文件**复制粘贴**进去（会弹管理员确认，点是）
   - 小提示：地址栏直接输入 `C:\Windows\SysWOW64` 回车最快
5. 双击导入注册表补丁 `restore_32bit_asio.reg`，弹窗都点是

**✅ 做完怎么验证**：文件管理器打开 `C:\Windows\SysWOW64`，能看到这两个文件（名字对得上就行）。

---

## 第 2 步：放 3 个文件进游戏目录（不用管理员）

**游戏目录在哪**：Steam 库 → 右键 Rocksmith → 管理 → 浏览本地文件
（一般长这样：`C:\Program Files (x86)\Steam\steamapps\common\Rocksmith2014`）

打开下载的 `release-0.7.5.zip`，把里面的 **3 个文件全部复制**到游戏目录里：

| 文件 | 说明 |
|---|---|
| `RS_ASIO.dll` | 核心（游戏启动时会自动加载它） |
| `avrt.dll` | 配套 |
| `RS_ASIO.ini` | 配置文件（下一步要改的就是它） |

> ⚠️ DLC 和游戏本体文件**一个都别动、别删**，只是"加"文件进去。

**✅ 做完怎么验证**：游戏目录里能看到这 3 个新文件。

---

## 第 3 步：改两个配置（记事本就行）

### 3.1 改 `RS_ASIO.ini`（游戏目录里那个）

方法：**记事本**打开它 → 全选 → 删掉 → 粘贴下面这份 → 保存（Ctrl+S）。

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

> 只想懂关键 4 行的意思：
> - `Driver=ASIO THRII` → 用 THR10II 自己的 ASIO 驱动（第 1 步恢复的那个）
> - `Channel=1`（输入）→ 只取**右声道**，右声道是"干声"（没加效果的原始音），游戏判定音高需要它
> - `SoftwareMasterVolumePercent=200` → 干声很弱，放大到 200%
> - `CustomBufferSize=128` → 声音缓冲（越小延迟越低、越容易爆音；这是平衡点）

### 3.2 检查 `Rocksmith.ini`（游戏目录里，游戏生成的）

记事本打开，找到 `[Audio]` 段，确认这 2 行**必须是**：

```ini
ExclusiveMode=1
Win32UltraLowLatencyMode=1
```

不是 1 就改成 1，保存。
（`LatencyBuffer=1` 也建议保持 1；调参口诀见第 4 步的常见问题表）

**✅ 做完怎么验证**：重新用记事本打开两个文件，看到的内容和你粘贴/改动的一致。

---

## 第 4 步：启动验证（3 个检查点）

**⚠️ 重点：不要开 Voicemeeter**（如果你以前装过它，先彻底关掉/退出）。

1. 从 Steam 启动游戏 → **没有报错弹窗**（有"exclusivity"报错 = Rocksmith.ini 没改对，回去看 3.2）
2. 主菜单 → **能听到背景音乐**（听不到：先查音箱音源键是不是 USB 档、音量拧大）
3. 进调音界面 → 弹一根弦 → **琴弦稳定停在音高上**（不乱跳 = 输入通了）

**✅ 终极验证（看日志）**：退出游戏后，用记事本打开游戏目录里的 `RS_ASIO-log.txt`，找这两行：
- 有 `Creating AsioSharedHost - dll: ...\SysWow64\YamahaTHRIIAsio_OnInterposer.dll` = 32 位组件生效 ✔
- **没有** `Failed to create ASIO buffers` = 一切正常 ✔

---

## 常见问题速查（出问题先看这里）

| 现象 | 先做这个 |
|---|---|
| 弹窗报"exclusivity" | `Rocksmith.ini` 的 `ExclusiveMode` 是不是又被改成 0 了？（游戏可能自己改回） |
| 调音乱跳、跟弹什么无关 | 99% 是第 1 步没做对 → 重跑脚本看 `[OK]`；确认没开 Voicemeeter |
| 有声音但爆音（噼啪） | 先把**音箱上 master / guitar volume / gain 旋钮往小拧**（别纠结是哪个）；还爆就把 `CustomBufferSize` 128→192→256 |
| 弹着感觉慢半拍 | `CustomBufferSize` 128 已经是甜点值；还觉得钝再降 96 试试（会开始爆音就别用） |
| 能玩但音符对不上动画 | 游戏内有"可视化延迟校准"（提示画面比声音慢那个），跟着**听到的**节拍点击，多测几次 |
| 报"设备正在使用"(0xC00D4E85) | 有别的程序独占着声卡，关掉它再开游戏 |
| 游戏重写了 ini 导致反复出问题 | 改好后把 `Rocksmith.ini` 设为只读（右键 → 属性 → 勾选只读） |

**改配置后记得重启游戏才生效。**

---

## 小词典（5 个词，够用了）

| 词 | 一句话解释 |
|---|---|
| ASIO | 一种专业音频接口，延迟低。游戏本来不用它，RS ASIO 让游戏用上它 |
| 32 位 / 64 位 | 程序的"口径"——Rocksmith 是 32 位，只能加载 32 位的驱动组件（这就是第 1 步存在的意义） |
| 干声 / 湿声 | 干声 = 吉他原始信号（游戏要它）；湿声 = 加了音箱模拟效果的声音（游戏不能要它） |
| SysWOW64 | 32 位程序在 64 位 Windows 上加载组件时去的地方（第 1 步的 DLL 就住这） |
| ini | 纯文本配置文件，记事本能改 |

---

*本指南配套：`configs/RS_ASIO.ini`（第 3.1 步的成品文件，直接复制也行）、`scripts/restore_32bit_asio.cmd`（第 1 步一键脚本）、`solution-layout.zh-CN.md`（完整布局图，想钻研再看）。*
