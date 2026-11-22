# Rodriguez

个人使用的 Arch Linux 二进制 pacman 仓库：包由 GitHub Actions 构建或镜像、签名，通过 GitHub Releases 的 `rolling` 标签分发。

[![repo](https://github.com/Moritz230127/rodriguez/actions/workflows/repo.yml/badge.svg)](https://github.com/Moritz230127/rodriguez/actions/workflows/repo.yml)
[![pacman](https://img.shields.io/badge/pacman-rolling-1793d1)](https://github.com/Moritz230127/rodriguez/releases/tag/rolling)
[![Arch Linux](https://img.shields.io/badge/Arch_Linux-x86__64-1793d1?logo=archlinux&logoColor=white)](https://archlinux.org)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> 这不是公共发行版，只维护个人使用的包；不承诺兼容性、更新频率或支持周期。
> 仓库公开是因为 pacman 需要匿名拉取 Release 资产，不代表对外提供支持。

## 快速开始

在 `/etc/pacman.conf` 末尾加入：

```ini
[rodriguez]
SigLevel = Required DatabaseOptional
Server = https://github.com/Moritz230127/rodriguez/releases/download/rolling
```

首次使用先导入并本地签名仓库公钥：

```bash
curl -fsSL https://github.com/Moritz230127/rodriguez/releases/download/rolling/packages.asc -o /tmp/rodriguez.asc
sudo pacman-key --add /tmp/rodriguez.asc
sudo pacman-key --lsign-key 028A4747923154F7
sudo pacman -Syu
```

安装 DeepSeek Harness Desktop：

```bash
sudo pacman -S deepseek-harness-desktop-wayland
dsh-wayland-doctor
```

> 不要只跑 `pacman -Sy` 装单个包；Arch 上请始终用 `pacman -Syu`，避免部分升级。

## 仓库里的包

| 包 | 说明 | 更新方式 |
|---|---|---|
| `deepseek-harness-desktop-wayland` | DeepSeek Harness Desktop（Arch/Wayland，Electron shell + 内置 dsh runtime）；`-git` 式跟踪上游 `master` | 构建仓发布后自动镜像 |
| `niri-side-note-bin` | Niri 侧笺：贴边便签笔记，预编译 | 自动跟随应用 Release |
| `gtk4-layer-shell` | Niri 侧笺依赖，GTK4 Layer Shell | 固定 1.3.0，升级时手动 bump |
| `kkdy-native` | 本地既有包 | 迁移时收录 |
| `grub-theme-bsol` | 本地既有包 | 迁移时收录 |

- DSH 的包名仍是 `deepseek-harness-desktop-wayland`，但语义是 `-git` 滚动包；`provides=('dsh')`，所以也可以按 `dsh` 解析。
- 包含本机 `/etc` 配置的 `local-arch` **没有**发布到这个公开仓库。

## 更新机制

```text
上游 dsh master / tag
  └─ deepseek-harness-desktop-wayland 构建仓
       5 分钟检查 master、1 小时 cooldown、新 tag 绕过
       └─ rolling release：包 → dsh.db → latest
             └─ repository_dispatch（或 15 分钟 cron 兜底）
                   └─ Rodriguez：下载、校验、重签、repo-add、发布
                         └─ pacman -Syu
```

- **DSH**：由 [deepseek-harness-desktop-wayland](https://github.com/Moritz230127/deepseek-harness-desktop-wayland) 从上游源码 + 最小补丁构建；本仓库只镜像它已发布的包，校验 `SHA256SUMS` 后用本仓库密钥重签，不在本仓库重编。
- **Niri 侧笺**：workflow 自动解析应用最新 Release 的 tag、资产名和 SHA-256，生成包并签名；同版本已存在会跳过。
- **gtk4-layer-shell**：上游低频依赖，固定在 1.3.0；升级时手动改 PKGBUILD 和 `pkgrel`。
- **数据库增量更新**：只下载旧 `rodriguez.db`，`repo-add` 新包后上传，不重新下载历史包。
- **不覆盖同版本资产**：同一 `pkgver-pkgrel` 一旦发布就不再覆盖；需要重建时先 bump `pkgrel`。
- Release 只保留最近 3 个版本化包；数据库只引用当前版本，删旧资产不影响升级。

## 签名与信任

- 包和数据库都由 `028A4747923154F7` 签名；`SigLevel = Required DatabaseOptional` 会强制校验包签名。
- 私钥只在本机和 GitHub Actions secret `REPO_GPG_KEY` 中；仓库、Release 里只有公钥。
- 公钥：`keys/packages.asc`，同一份也发布在 Release 里。
- 密钥轮换：同时发布新旧公钥；客户端 `pacman-key --add` 后 `--lsign-key`，旧公钥保留到旧包全部过期。

## DSH 说明

- **`-git` 语义**：`pkgver = <上游版本>.r<相对最近 tag 的提交数>.g<短 SHA>`，每次构建固定一个 40 位上游 commit；master 构建有 1 小时 cooldown，上游新 tag 会绕过。
- **诊断**：安装后运行 `dsh-wayland-doctor`，只读检查会话、GPU、niri 的 explicit sync / `wait-for-frame-completion-before-queueing`、dsh 的 GPU 进程与日志。
- **NVIDIA + niri**：niri 26.04 还没有 `linux-drm-syncobj-v1`；NVIDIA 下建议在 niri 的全局 `debug {}` 加 `wait-for-frame-completion-before-queueing`，不要对 dsh 做按窗口的圆角/透明度覆盖——外观保持全局一致。原理和回退见构建仓的 [`docs/nvidia-niri.md`](https://github.com/Moritz230127/deepseek-harness-desktop-wayland/blob/main/docs/nvidia-niri.md)。
- 详细打包、补丁和构建说明见构建仓 README。

## 故障排查

| 症状 | 先看 |
|---|---|
| `pacman -Sy` 404 / 签名失败 | 公钥是否 `--add` + `--lsign-key`；`SigLevel` 是否为 `Required DatabaseOptional` |
| `checkupdates` 没有 DSH 新版本 | [构建仓 Actions](https://github.com/Moritz230127/deepseek-harness-desktop-wayland/actions)、本仓 Actions、`ci-failure` / `mirror-failure` issue |
| DSH 启动失败 / 显示异常 | `dsh-wayland-doctor`；`journalctl --user -u niri`；附 `pacman -Q deepseek-harness-desktop-wayland` |
| 升级后回滚 | `sudo pacman -U <旧版本 .pkg.tar.zst URL>`；Release 保留最近 3 个版本 |

## 目录结构

```text
pkgs/                        PKGBUILD（niri-side-note-bin、gtk4-layer-shell）
.github/workflows/repo.yml   构建/镜像、签名、增量数据库、发布
keys/packages.asc            仓库签名公钥
scripts/migrate-local.sh     从旧 [dsh]/[localrepo] 配置迁移到 [rodriguez]
```

Release 资产是扁平的：`rodriguez.db`、`rodriguez.files`、`*.pkg.tar.zst` 及对应 `.sig` 都在 `rolling` 这一个 Release 下。

## 从旧配置迁移

如果本机还保留旧的 `[dsh]` / `[localrepo]` 配置：

```bash
git clone https://github.com/Moritz230127/rodriguez.git
cd rodriguez
sudo ./scripts/migrate-local.sh
```

脚本会备份 `/etc/pacman.conf`、移除旧仓库段、加入 `[rodriguez]`、导入并本地签名公钥，然后 `pacman -Syu`。`/srv/localrepo` 不会自动删除，确认 `pacman -Sl rodriguez` 正常后再手动清理。

## 许可证

仓库脚本与打包文件以 MIT 发布；各软件包沿用上游许可证（Niri 侧笺 MPL-2.0，gtk4-layer-shell MIT，DSH 见其上游仓库）。
