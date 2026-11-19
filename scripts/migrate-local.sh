#!/usr/bin/env bash
# 将本机 [dsh] / [localrepo] 迁移到 [rodriguez]。
# 需要 root；会先备份 /etc/pacman.conf。
set -euo pipefail

(( EUID == 0 )) || { echo "请用 sudo 运行：sudo $0" >&2; exit 1; }

REPO_NAME=rodriguez
SERVER="https://github.com/Moritz230127/rodriguez/releases/download/rolling"
KEYID="028A4747923154F7"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF=/etc/pacman.conf
STAMP=$(date +%Y%m%d-%H%M%S)

cp -a "$CONF" "$CONF.bak-$STAMP"
echo "已备份：$CONF.bak-$STAMP"

python3 - "$CONF" "$REPO_NAME" "$SERVER" <<'PY'
import re
import sys

path, repo, server = sys.argv[1:4]
text = open(path, encoding="utf-8").read()

for section in ("dsh", "localrepo"):
    text = re.sub(rf"(?ms)^\[{re.escape(section)}\].*?(?=^\[|\Z)", "", text)

block = f"""[{repo}]
SigLevel = Required DatabaseOptional
Server = {server}
"""

if re.search(rf"(?m)^\[{re.escape(repo)}\]\s*$", text):
    text = re.sub(rf"(?ms)^\[{re.escape(repo)}\].*?(?=^\[|\Z)", block, text)
else:
    text = text.rstrip() + "\n\n" + block

open(path, "w", encoding="utf-8").write(text)
PY

pacman-key --add "$HERE/keys/packages.asc" 2>/dev/null || true
pacman-key --lsign-key "$KEYID"

echo "== 同步 =="
pacman -Syu

echo "== 仓库内容 =="
pacman -Sl "$REPO_NAME"

echo
echo "迁移完成。确认后再手动清理："
echo "  sudo rm -rf /srv/localrepo"
