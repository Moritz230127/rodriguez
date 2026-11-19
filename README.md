# Rodriguez

个人使用的 Arch Linux 二进制 pacman 仓库，构建产物通过 GitHub Release 分发。

> 仓库本身是公开的：pacman 匿名拉取 Release 资产，GitHub 私有仓库的 Release 资产无法被 pacman 直接下载。
> 这不是一个公共发行版，只维护我个人使用的包；不承诺兼容性、更新频率或支持周期。

## 客户端配置

```ini
[rodriguez]
SigLevel = Required DatabaseOptional
Server = https://github.com/Moritz230127/rodriguez/releases/download/rolling
```

首次使用先信任签名公钥：

```bash
curl -fsSL https://github.com/Moritz230127/rodriguez/releases/download/rolling/packages.asc -o /tmp/rodriguez.asc
sudo pacman-key --add /tmp/rodriguez.asc
sudo pacman-key --lsign-key 028A4747923154F7
sudo pacman -Syu
```

安装 Niri 侧笺：

```bash
sudo pacman -S niri-side-note-bin
```

## 仓库里的包

| 包 | 说明 |
|---|---|
| `niri-side-note-bin` | Niri 侧笺：贴边便签笔记，预编译二进制 |
| `gtk4-layer-shell` | Niri 侧笺运行时依赖，Layer Shell 的 GTK4 绑定 |
| `deepseek-harness-desktop-wayland` | 从上游 DSH Release 镜像并重新签名 |
| `kkdy-native` | 本地既有包，迁移时收录 |
| `grub-theme-bsol` | 本地既有包，迁移时收录 |

`local-arch` **没有**发布到这个公开仓库：它包含 `/etc` 系统配置、NetworkManager、sudoers 等内容，不适合公开。它保持本机安装状态，不再由 `[localrepo]` 更新。

## 签名与信任

- 包和数据库都由 `028A4747923154F7` 签名；`SigLevel = Required DatabaseOptional` 会强制校验包签名。
- 私钥只在本机和 GitHub Actions secret `REPO_GPG_KEY` 中；服务器/仓库不保存可用于签发新包的密钥。
- 公钥：`keys/packages.asc`，同一份也发布在 Release 里。
- 密钥轮换时同时发布新旧公钥，客户端 `pacman-key --add` 后 `--lsign-key`，不要删除旧公钥直到旧包全部过期。

## 目录结构

```text
pkgs/
  niri-side-note-bin/     预编译 Niri 侧笺
  gtk4-layer-shell/       GTK4 Layer Shell
.github/workflows/repo.yml 构建、签名、增量数据库、发布
keys/packages.asc          仓库签名公钥
scripts/migrate-local.sh   本机从 [dsh]/[localrepo] 迁移到 [rodriguez]
```

Release 资产是扁平的：`rodriguez.db`、`rodriguez.files`、`*.pkg.tar.zst` 以及对应 `.sig` 全部放在 `rolling` 这一个 Release 下。`repo-add` 生成的是符号链接，上传前已复制成真实文件。

## 更新流程

- Niri 侧笺：应用源码在 <https://github.com/Moritz230127/niri-side-note>；发布新 tag 后，更新 `pkgs/niri-side-note-bin/PKGBUILD` 的版本与校验和，运行 workflow 或本地重新签名上传。
- gtk4-layer-shell：版本更新时改 `pkgs/gtk4-layer-shell/PKGBUILD` 并重建。
- DSH：上游 CI 继续追 DSH 官方 commit/tag 并打补丁；本仓库只镜像它已发布的包，校验 `SHA256SUMS` 后用本仓库密钥重新签名，不在 VPS 或本仓库重编。
- 数据库增量更新：workflow 只下载旧 `rodriguez.db`，`repo-add` 新包后上传，不会重新下载全部历史包。
- 同一 `pkgver-pkgrel` 的资产一旦发布就不再覆盖；需要重建时先 bump `pkgrel`，否则 workflow 会跳过已存在的资产。

- 旧版本目前手动清理；数据库只引用最新版，删除旧资产不影响升级。计划后续在工作流里加入按版本保留 2 个资产的清理步骤。

## 本地迁移

```bash
git clone https://github.com/Moritz230127/rodriguez.git
cd rodriguez
sudo ./scripts/migrate-local.sh
```

脚本会备份 `/etc/pacman.conf`、移除 `[dsh]` 与 `[localrepo]`、加入 `[rodriguez]`、导入并本地签名公钥，然后执行 `pacman -Syu`。`/srv/localrepo` 不会自动删除，确认 `pacman -Sl rodriguez` 正常后再手动清理。

## 许可证

仓库脚本与打包文件以 MIT 发布；各软件包沿用其上游许可证（Niri 侧笺为 MPL-2.0，gtk4-layer-shell 为 MIT，DSH 见其上游仓库）。
