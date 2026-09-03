# 复刻包：搞通之后的完整文件布局（THR10II 直连方案）

> 本文件回答一个问题："一切就绪之后，你的电脑上应该长什么样？"
> 照着这个布局核对，就能确认方案是否完整落地。

---

## 1. 总览：三处位置

| # | 位置 | 放什么 | 来源 |
|---|---|---|---|
| 1 | 游戏根目录（3 个文件） | `RS_ASIO.dll`、`avrt.dll`、`RS_ASIO.ini` | rs_asio 官方 release（建议 v0.7.5 及以上） |
| 2 | `C:\Windows\SysWOW64`（2 个 DLL） | `YamahaTHRIIAsio_OnInterposer.dll`、`InterposerTHRIIBackend.dll` | **v1.0.0.0 安装包**（Yamaha 官网）提取 |
| 3 | 注册表（32 位节点） | `ASIO THRII` 键 + CLSID | 脚本自动写入（或导入 .reg） |

---

## 2. 游戏根目录（改动后）

```
Rocksmith2014\  (Steam 目录)
├── Rocksmith2014.exe          ← 原有
├── Rocksmith.ini              ← 原有，但已改为（[Audio] 段）：
│       ExclusiveMode=1
│       Win32UltraLowLatencyMode=1
│       LatencyBuffer=1        （可按需 1~4）
│
├── RS_ASIO.dll                ← 新增（release zip 里的）
├── avrt.dll                   ← 新增（release zip 里的）
├── RS_ASIO.ini                ← 新增/替换（本仓库 configs/ 里有一份配好的，
│                                 复制过来即可，Driver 已填 ASIO THRII）
│
└── (你的 DLC、mod 等原有文件一律不动)
```

## 3. SysWOW64（系统 32 位组件目录）

```
C:\Windows\SysWOW64\
├── YamahaTHRIIAsio_OnInterposer.dll   ← 新增（v1 包提取，32 位）
└── InterposerTHRIIBackend.dll         ← 新增（v1 包提取，32 位）
```

> 为什么放这里：Rocksmith 是 32 位进程，只能加载 32 位目录（SysWOW64）里的组件。
> 64 位驱动栈（System32 里的 `ThriiAsio_OnInterposer_x64.dll` 等）**保持原样**——这就是
> "驱动不降级"的关键：Cubase 等 64 位程序继续用 64 位栈，游戏用 32 位组件。

## 4. 注册表（32 位 ASIO 注册项）

```
HKLM\SOFTWARE\WOW6432Node\ASIO\ASIO THRII
    "CLSID"       = {4A1C1DA6-7749-41D5-A13F-AED70386C0F8}
    "Description" = "ASIO THRII"

HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\{4A1C1DA6-7749-41D5-A13F-AED70386C0F8}\InprocServer32
    (默认)          = C:\WINDOWS\SysWow64\YamahaTHRIIAsio_OnInterposer.dll
    "ThreadingModel" = "Apartment"
```

> 多数机器上这组键是 v1 旧安装残留的"空壳"（注册还在、DLL 没了）——
> 只需补回 DLL 文件即可复活；如果注册表干净，用脚本或 .reg 补上。

---

## 5. 怎么落地（两条路）

**路线 A：一键脚本（推荐新手）**
1. 下载本仓库 `scripts/restore_32bit_asio.cmd`
2. **右键 → 以管理员身份运行**
3. 脚本自动：下载 v1 包（Yamaha 官网）→ 7-Zip 解包 → 复制 2 个 DLL → 写注册表 → 校验
   （也可以把本地已有的 v1 安装包直接拖到脚本图标上，跳过下载）

**路线 B：手动**
1. 下载 Yamaha 官网 v1.0.0.0 安装包（zip 版）
2. 7-Zip 解开安装 exe，取出 `Driver Archive\THRII\` 里的 2 个 DLL
3. 以管理员身份复制进 `C:\Windows\SysWOW64\`
4. 双击导入 `scripts/restore_32bit_asio.reg`（或手动建键）

**然后（两条路都一样）：**
1. 从 rs_asio 官方 release 下载 zip（建议 v0.7.5）
2. 把 `RS_ASIO.dll`、`avrt.dll` 放进游戏根目录
3. 把 `configs/RS_ASIO.ini` 复制到游戏根目录（覆盖模板）
4. 确认 `Rocksmith.ini` 的 `ExclusiveMode=1`（游戏可能重写它，进不去就改回来）
5. **不要运行 Voicemeeter**，直接启动游戏

---

## 6. 验收清单（全绿才算落地）

| 检查 | 方法 |
|---|---|
| DLL 就位 | `C:\Windows\SysWOW64\YamahaTHRIIAsio_OnInterposer.dll` 存在（约 266 KB） |
| 注册就位 | 运行 `reg query "HKLM\SOFTWARE\WOW6432Node\ASIO\ASIO THRII"` 有输出 |
| 游戏加载成功 | 游戏根目录 `RS_ASIO-log.txt` 出现 `Creating AsioSharedHost - dll: ...YamahaTHRIIAsio_OnInterposer.dll`，且**没有** `Failed to create ASIO buffers` |
| 输入是干声 | 调音界面弹弦，琴弦稳定停在音高（不随播放内容乱跳） |
| 输出正常 | 主菜单有背景音乐，无爆音（有爆音先拧小音箱旋钮，见附录 C） |

---

## 7. 版权与安全说明

- **Yamaha 的 DLL 文件有版权，本仓库不上传**——脚本只是从 Yamaha 官方地址
  下载、解包、复制，等价于"替新手跑一遍安装流程"，不涉及文件分发。
- 本方案**不安装 v1 内核驱动**，不触碰 64 位驱动栈，不影响 Win11 内存完整性。
- 需要管理员权限的只有：复制 DLL 到 SysWOW64、写 HKLM 注册表。