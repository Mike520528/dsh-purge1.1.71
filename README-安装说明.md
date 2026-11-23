# dsh-purge 1.1.71（rc.2 适配版）

给 **DeepSeek Harness 0.2.0-rc.2** 用的破甲插件。原版 1.1.71 在这里装不上/装一半，这个版本改好了，装上就能用。

---

## 包里有什么

| 文件 | 说明 |
|---|---|
| `安装.cmd` | **双击这个**。自动提权调用下面的脚本，跑完停住等你看结果 |
| `install.ps1` | 安装脚本本体（自动找 DSH、校验版本、备份、写入、装依赖） |
| `dsh-purge-1.1.71-rc2.tgz` | 改好的插件包（npm 格式，1,457,232 字节） |
| `README-安装说明.md` | 本文件 |

---

## 装之前必须确认

**你的 DeepSeek Harness 必须是 `0.2.0-rc.2`。**

查看方法：右键 `DeepSeek Harness.exe` → 属性 → 详细信息 → 文件版本。

不是 rc.2 就别装。这个包里的每条补丁都靠字符串锚点定位具体代码行，版本一变锚点就对不上——**装上去不会报错，但会静默失效一部分**，比装失败更麻烦。

---

## 安装：自动

**双击 `安装.cmd`**，读完窗口里的输出，按任意键关闭。

不想双击就在 PowerShell 里跑：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

（一定要带 `-ExecutionPolicy Bypass`，默认策略会拦这个脚本。）

它会依次做这些事：

1. 自动找到 `DeepSeek Harness.exe`（跑着的进程 → 未安装程序列表 → 常见路径）
2. 读出文件版本，不是 `0.2.0-rc.2` 就中止（退出码 2）
3. 找到 `%USERPROFILE%\.dsh\profiles\desktop\package.json`，**先备份**成 `package.json.bak-日期时间`
4. 检查有没有装 `Xsdsh-purge` 或 `dsh-purge-community`，有就报冲突退出（退出码 3）
5. **把 tgz 复制一份到 `profiles\desktop\_local-plugins\`**，之后你删掉这个压缩包文件夹也不影响
6. 往 `dependencies` 加一条 `file:` 指向 `_local-plugins` 里那份，往 `dsh.profile.bundles` 加 `dsh-purge`
7. 优先用 DSH 内置的 pnpm 跑 `pnpm install`；找不到就手动解包到 `node_modules\dsh-purge`
8. 打印结果

装完**完全退出并重启 DeepSeek Harness**。

DSH 装在别的盘就用参数指定：

```powershell
.\install.ps1 -DshExe "D:\新建文件夹\DeepSeek Harness.exe"
```

---

## 安装：手动（不想跑脚本时）

```powershell
# 1. 找到 profile 目录
cd "$env:USERPROFILE\.dsh\profiles\desktop"

# 2. 备份
Copy-Item package.json "package.json.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"

# 3. 解开插件
$dest = "node_modules\dsh-purge"
New-Item -ItemType Directory -Force $dest | Out-Null
tar -xzf "<本目录>\dsh-purge-1.1.71-rc2.tgz" -C $dest --strip-components=1

# 4. 编辑 package.json，加两处
```

`package.json` 里加：

```json
{
  "dependencies": {
    ...现有内容...,
    "dsh-purge": "file:C:/完整路径/dsh-purge-1.1.71-rc2.tgz"
  },
  "dsh": {
    "profile": {
      "bundles": [
        ...现有内容...,
        "dsh-purge"
      ]
    }
  }
}
```

然后重启 DSH。

---

## 这个版本改了什么

原始 1.1.71 的 `package.json` 有三处会让人装上后踩坑，都改了：

### 1. 加了 `engines.dsh`（关键）

```diff
  "engines": {
-   "node": ">=18"
+   "node": ">=18",
+   "dsh": "0.2.0-rc.2"
  }
```

原版**没有** `engines.dsh`，DSH 不会校验宿主版本，装到 rc.5 上也照样装上去，然后补丁静默错位。

DSH 的判定在 `dsh-app-boot/lib/index.js:276-284`：

```js
function satisfies(runtimeVersion, range) {
  return range.trim() !== "" && semver.satisfies(runtimeVersion, range, { includePrerelease: true });
}
```

加了这行之后，版本不对会被直接拦下，而不是装上去装死。

### 2. 删掉了 `dsh.install` 段

```diff
  "dsh": {
    "bundle": { "patch": "./cordis.patch.yml" },
-   "install": {
-     "preferred": "tarball",
-     "tarball": "https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz",
-     "zip": "...master.zip",
-     "git": "https://github.com/YuJunZhiXue/dsh-purge.git"
-   },
    "client": { ... }
  }
```

原版这几个 URL 指向 **master 分支**，现在 master 是 1.1.90。谁要是点了"自动安装"，拉下来的根本不是 1.1.71。而且 GitHub 上 **没有 v1.1.71 这个 tag**（实测 404，tag 列表只到 v1.1.81 起），所以也没法改成固定 tag。直接删掉，只走本地包。

### 3. `dshTarget` 保持 `0.2.0-rc.2`

原版就是这个值，没动。

**没改任何代码。** `lib/`、`bin/`、`presets/`、`skills/`、`cordis.patch.yml` 全部与原始发布包逐字节一致（104 个文件，3,419,012 字节）。

---

## 校验值

改版包：

```
文件名   dsh-purge-1.1.71-rc2.tgz
大小     1,457,232 字节
SHA-256  F18AFB5070F735403C32E9A6C50D20BA8B6278C8E813ABD3A98B2D94BEB82167
```

（以实际收到的文件为准，重新打包的 SHA-256 会变，但里面的代码应该与下面这份原始包一致。）

原始 1.1.71（未改）：

```
文件名   dsh-purge-1.1.71.tgz
大小     1,456,103 字节
SHA-256  0C18BFF7F4C1CA98068AE5F83531FD8FB4EE9E724F1CDE27DAE529BC601A3C24
```

---

## 不要和 Xsdsh-purge 一起装

`Xsdsh-purge` 4.x 是同一个作者的重构版（源码目录形态，target rc.5）。它和这个包**往同一批文件打补丁**：

- `app.asar.unpacked\dsh\node_modules\@deepseek-ai\dsh-system-prompt\lib\index.js`
- `...\dsh-agent-loop\lib\index.js`
- `...\dsh-user-approval\lib\index.js`
- 等等同一批

锚点不同，装了会互相覆盖，最后状态是混乱的。**二选一。**

---

## 卸载

```powershell
cd "$env:USERPROFILE\.dsh\profiles\desktop"
Copy-Item package.json "package.json.bak-uninstall-$(Get-Date -Format yyyyMMdd-HHmmss)"
```

编辑 `package.json`，删掉 `dependencies` 里的 `"dsh-purge"` 一行，以及 `dsh.profile.bundles` 里的 `"dsh-purge"`，然后重启 DSH。

再顺手删掉这两处实体：

```powershell
Remove-Item "node_modules\dsh-purge" -Recurse -Force
Remove-Item "_local-plugins\dsh-purge-1.1.71-rc2.tgz" -Force
```

补丁残留会留在 `app.asar.unpacked` 里。想彻底还原，在 DSH 里用插件自带的还原功能，或者用 `app.asar.xsdshpurge-bak` 那份备份恢复对应文件。

---

## 排错

| 现象 | 原因 | 处理 |
|---|---|---|
| 脚本说"找不到 DeepSeek Harness.exe" | 装在非标准路径 | `-DshExe "完整路径"` |
| 脚本中止说版本不匹配 | 你的 DSH 不是 rc.2 | 换对应的插件版本，别硬装 |
| 脚本说"检测到冲突插件" | 已装 Xsdsh-purge 或 community | 先卸掉那个，二选一 |
| 装完启动报"插件不兼容" | `engines.dsh` 校验没过 | 说明版本确实不对；确要装按提示跑 `dsh plugin allow-version` |
| 装完没反应 | 没重启 | 完全退出 DSH 再开 |
| `pnpm install` 报错 | 网络或 pnpm 路径问题 | 脚本会自动转手动解包，看后续输出 |

---

## 它到底是干什么的

抓救命用的破甲插件。它给 DSH 的 63 个位置打补丁（提示词里的身份剥离、审批策略改 never、沙箱护栏放宽、工具调用失败放行等），本机实测 `59/63 applied, 0 pending, 4 skipped`。

补丁写在 `resources\app.asar.unpacked\` 下，靠 Electron 的 unpacked 覆盖机制生效，不修改 `app.asar` 本体。所以：

- 生效判断看 `app.asar.unpacked` 里的文件内容，不是看 `app.asar` 有没有被改
- 界面里如果显示"app.asar: 还在"，那是旧判据的误报，不影响