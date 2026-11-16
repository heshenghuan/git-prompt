# PowerShell 提示符显示 Git 分支 + 分类改动计数（轻量版）

参考：[PowerShell 中 Prompt 显示 Git 分支 · aggresss](https://blog.csdn.net/aggresss/article/details/112131444)

本目录三个文件：

| 文件 | 用途 |
| --- | --- |
| `git-prompt.ps1` | 提示符脚本本体（配置项 + 三个函数 + 末尾自动启用） |
| `install-git-prompt.ps1` | 可选：把脚本追加进 PowerShell profile（带备份、可卸载） |
| `README.md` | 本说明 |

## 效果

```
PS D:\Projects\demo> (main)                    ← 干净
PS D:\Projects\demo> (main)+3 *2               ← 3 个已暂存，2 个未暂存修改
PS D:\Projects\demo> (main)?1                  ← 1 个未跟踪文件
PS D:\Projects\demo> (main)+1 *2 ?1            ← 混合
PS D:\Projects\demo> (tag:v1.0.0)              ← 游离 HEAD 且正好在 tag 上
PS D:\Projects\demo> (commit:8f3a1c2)          ← 游离 HEAD 在普通提交上
```

所有标记都是纯 ASCII：`+` 已暂存（绿色）、`*` 未暂存修改（黄色）、`?` 未跟踪（深灰）。
已在本机 Windows PowerShell 5.1 实测：干净 / 仅暂存 / 仅修改 / 未跟踪 /
同文件同时暂存+修改 / 关闭未跟踪 / 可选 ⚡ / `git_prompt` 开关，全部正常。

## 原理速览

1. PowerShell 每次画提示符都会调用 `prompt` 函数；覆盖它即可自定义。
2. **分支名**：直接读 `.git/HEAD`（内容形如 `ref: refs/heads/main`），
   不启动 git 进程；从 `$PWD` 向上找 `.git/HEAD`，仓库子目录也有效；
   上次读到的内容缓存在 `$Global:GIT_NAME_HEAD`，没变就跳过解析。
3. **分类计数**：只要在仓库里，每次提示符执行一次
   `git --no-optional-locks status --porcelain`，然后按 porcelain 的 `XY` 两列分类：
   - `X` 列非空 → 已暂存（`+`）
   - `Y` 列非空 → 未暂存修改（`*`）
   - `??` 开头 → 未跟踪（`?`）
   三种计数都来自这**同一个进程**的输出，不额外起 git；`--no-optional-locks`
   避免提示符和你的 git 命令抢 index.lock。
4. **开关**：`Copy-Item Function::Global:...` 把原 `prompt` 存成 `prompt_bak`，
   新的 `prompt_custom` 先调 `prompt_bak` 画出原来的 `PS C:\path>`，再补 `(分支)`；
   再执行一次 `git_prompt` 还原。

## 为什么全部用 ASCII 标记

试过 `✔`（U+2714）、`√`（U+221A）、`✎`（U+270E）这些“好看”的符号，结论是坑太多：

- `✔` 是 emoji-capable 字符：终端可能用颜色 emoji 字体画它，字形自带颜色
  （实测显示成紫色），`Write-Host -ForegroundColor` 不生效；拼 `U+FE0E`（VS15）
  强制文本呈现在该终端也**无效**；
- 这些符号在中文区域设置下还可能被算作宽字符（字形 2 格、终端推进 1 格），
  紧跟的数字就叠上去；
- 换成非 emoji 的 `√` 颜色正常了，但你不想再赌字体/终端的差异。

ASCII 字符（`+ * ?`）没有 emoji 归属、宽度确定、任何字体都有、一定跟随
`-ForegroundColor`，所以现在是默认方案。

想换风格直接改脚本开头（都是 ASCII 字符串，随意）：

```powershell
$Global:GIT_PROMPT_STAGED_MARK = '+'   # 也可用 'A'、'S'
$Global:GIT_PROMPT_MODIFIED_MARK = '*' # 也可用 '~'、'M'
$Global:GIT_PROMPT_UNTRACKED_MARK = '?'# 也可用 'U'
$Global:GIT_PROMPT_COUNT_SEP = ' '     # 想变成 "+ 3 * 2" 就设成空格
```

## 可调项（脚本开头）

```powershell
$Global:GIT_PROMPT_DIRTY_MARK = ''      # 想额外加前缀就写 '!' 之类
$Global:GIT_PROMPT_STAGED_MARK = '+'    # 已暂存
$Global:GIT_PROMPT_MODIFIED_MARK = '*'  # 未暂存修改
$Global:GIT_PROMPT_UNTRACKED_MARK = '?' # 未跟踪
$Global:GIT_PROMPT_COUNT_SEP = ''       # 符号与数字之间的间隔（'' = 紧凑）
$Global:GIT_PROMPT_SHOW_UNTRACKED = $true  # $false = 完全忽略未跟踪
$Global:GIT_PROMPT_DIRTY_TTL_MS = 0     # 0=每次都检查；嫌慢改成 800（毫秒）
$Global:GIT_PROMPT_SHOW_DIRTY = $true   # $false 就只显示分支
$Global:GIT_PROMPT_BRANCH_PREFIX = '('
$Global:GIT_PROMPT_BRANCH_SUFFIX = ')'
```

改完重开窗口。

## 计数口径

- 同一个文件既暂存又修改，会同时计入 `+` 和 `*`；
- 重命名算 1 条，进 `+`；
- 冲突文件（如 `UU`）会同时计入两栏；
- 未跟踪的新文件每个算 1 条 `?`，可用 `GIT_PROMPT_SHOW_UNTRACKED=$false` 整体忽略。

## 安装（手动，推荐）

1. 打开 profile：

   ```powershell
   notepad $PROFILE.CurrentUserAllHosts
   ```

   Windows PowerShell 5.1 的路径：`~\Documents\WindowsPowerShell\profile.ps1`
   （PowerShell 7 是 `Documents\PowerShell\profile.ps1`，装了 7 再装一遍）

2. 把 `git-prompt.ps1` 整段粘贴到文件末尾，保存。
   **保持英文/ASCII 注释**：PS 5.1 会把无 BOM 的 UTF-8 当 ANSI 读，中文注释会乱码。

3. 重开终端，或当前窗口 `. $PROFILE`。

4. `cd` 进任意仓库验证；输入 `git_prompt` 可随时开关。

### 已经装过旧版（`branch:[main]>`、`(main)⚡3`、`(main)√3` 等）

把 profile 里整段替换成新版即可，或：

```powershell
.\install-git-prompt.ps1 -Uninstall
.\install-git-prompt.ps1
```

## 用安装脚本（可选，自己执行）

```powershell
.\install-git-prompt.ps1              # 追加到 5.1 profile，自动备份 .bak-时间戳
.\install-git-prompt.ps1 -Uninstall   # 删除该区块，profile 恢复原样
```

## 性能说明

- 分支部分几乎零成本：一次 `Get-Content`（本机实测约 1 ms）。
- 计数部分每次提示符要起一个 git 进程。本机 11245 文件的仓库实测
  `git status --porcelain` 约 90 ms，但**进程启动本身在这台机器的沙箱里就要约 35–47 ms**
  （`cmd /c exit` 也 34 ms），普通用户终端里通常只是 10–20 ms 量级。
  分类计数只是对已有输出做一次字符串循环（只遍历有改动的行），没有可测量的增量。
- 如果觉得回车变慢，把 `GIT_PROMPT_DIRTY_TTL_MS` 设成 800（最多每 0.8 s 检查一次，
  期间三种计数一起复用缓存），或 `GIT_PROMPT_SHOW_DIRTY = $false` 只留分支。

## 已知边界

- `.git` 是**文件**的场景（`git worktree`、子模块）检测不到，不显示分支；
- 路径名含 `[` `]` 时 `Test-Path` 按通配符处理，可能失效；
- 不显示 ahead/behind；游离 HEAD 才调用 `git describe`，慢一点但不常见。
