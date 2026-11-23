# dsh-purge 1.1.71 rc.2 适配版

给 **DeepSeek Harness 0.2.0-rc.2** 用的「破甲插件」安装包。原版 dsh-purge 1.1.71 在 rc.2 上装不上，这个包按 rc.2 的文件内容重新定位了补丁，改好了状态。

> 本仓库是**可安装的分发包仓库**，不包含插件源码，只包含打包好的安装产物。

---

## 包内文件

| 文件 | 字节数 | 作用 |
| --- | ---: | --- |
| `dsh-purge-1.1.71-rc2.tgz` | 1,457,232 | npm 格式的插件包，安装时解包到 `node_modules/dsh-purge` |
| `install.ps1` | 7,742 | 安装脚本：自动找 DSH、校验版本、备份、写入 package.json、装依赖 |
| `README-安装说明.md` | 7,424 | 中文安装说明 |
| `安装.cmd` | 511 | 双击入口，提权调用 `install.ps1` |

---

## 安装

**方式一（推荐）**：解压后双击 `安装.cmd`，会提权并调用 `install.ps1`。

**方式二（命令行）**：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### 参数

| 参数 | 说明 |
| --- | --- |
| `-DshExe <路径>` | 手动指定 `DeepSeek Harness.exe` 的完整路径，脚本找不到时用这个 |
| `-Force` | 版本不匹配也强行安装（不推荐——补丁按 rc.2 文件定位，换版本会静默错位） |

### 安装流程（脚本内部步骤）

1. 定位 `DeepSeek Harness.exe`（先看运行中的进程，再看常见安装路径和注册表卸载项）
2. 校验版本必须等于 `0.2.0-rc.2`，不符则中止（除非加 `-Force`）
3. 找到 DSH profile（默认 `$HOME\.dsh\profiles\desktop`）
4. 冲突检查：若已装 `Xsdsh-purge` 或 `dsh-purge-community`，中止（两者都往 `app.asar.unpacked` 打补丁，同时启用会互相覆盖）
5. 备份当前 `package.json`
6. 把 `dsh-purge-1.1.71-rc2.tgz` 复制到 profile 内 `_local-plugins/` 固化，之后删掉安装包目录也不影响已装插件
7. 改写 profile `package.json`：写入 `dependencies.dsh-purge` 和 `dsh.profile.bundles`
8. 优先用 DSH 自带的 pnpm 安装依赖；找不到 pnpm/node 则用 `tar` 手动解包到 `node_modules/dsh-purge`
9. 完全退出并重启 DeepSeek Harness 生效

---

## 卸载 / 回滚

脚本**没有自动卸载**，需要手动操作：

1. 编辑 profile 目录下的 `package.json`（默认 `$HOME\.dsh\profiles\desktop\package.json`）
2. 移除两处引用：
   - `dependencies` 里的 `"dsh-purge": "file:..."`
   - `dsh.profile.bundles` 数组里的 `"dsh-purge"`
3. 完全退出并重启 DeepSeek Harness

### 回滚到安装前

安装时脚本会把原 `package.json` 备份为同目录下的 `package.json.bak-yyyyMMdd-HHmmss`（时间戳后缀）。要回滚，把对应 `.bak` 文件还原成 `package.json`，然后重启 DSH 即可。

---

## 已知限制

- 只在 **DeepSeek Harness 0.2.0-rc.2** 上验证过。补丁按该版本的文件内容定位，换版本会静默错位，强装（`-Force`）可能部分失效。
- 与 `Xsdsh-purge`、`dsh-purge-community` 互斥，不能同时启用。
- 卸载需手动改 `package.json`，无自动卸载脚本。
