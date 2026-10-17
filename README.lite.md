# Mihomo Lite（HAMAN23333/mihomo）

本 fork 的发行可执行文件只使用 Lite 构建档案：

```text
with_gvisor no_tailscale no_zerotier no_easytier
```

Tailscale、ZeroTier、EasyTier outbound 被禁用，配置使用它们会明确报错。Tailscale 和 EasyTier 的 DNS 引用可能在查询时才失败。其他能力继续继承上游；Lite 不承诺特定体积或内存占用。

所有上游目标均提供非 UPX 变体，资产名为 `mihomo-lite-<OS>-<目标>-<版本>.gz`（Windows 为 `.zip`）。通过验证的目标额外提供 `mihomo-lite-<OS>-<目标>-upx-<版本>` 资产。UPX 只是同一次编译结果的副本经过压缩，功能边界相同。命令、容器内程序和系统包名仍为 `mihomo`。下载 URL 与上游资产命名不同。

系统包和容器始终使用非 UPX 变体。源码、vendor、工具链与校验和资产继续保留。Go module 文件出现三个 SDK 不代表最终二进制链接它们。

## 本地构建

安装 Go 后，在 Git Bash 或 Bash 中运行：

```bash
bash build-local.sh
```

输出位于 `bin/local/`，保留原有 Windows amd64-v3、Linux amd64-v3、Linux arm64 目标。amd64-v3 需要支持对应指令集的 CPU。标签数据源为 `scripts/lite-tags.txt`。

若已安装 UPX，可选择复制并压缩本地二进制；不自动下载工具，任何压缩或完整性检查失败都会终止：

```bash
bash build-local.sh --upx
```

本地 UPX 尝试不代表对应目标已经进入发布准入清单。发布目标以 `scripts/upx-targets.txt` 为准，工具版本与归档 SHA-256 固定在 `scripts/install-upx.sh`。新增目标必须补充格式支持、`upx -t` 和适用原生运行验证证据。

初始发布 UPX 准入仅为 `windows-amd64-v1`。2026-10-17 在 Windows 11 amd64、标准 Go 1.27.2 下构建，使用 SHA-256 已校验的 UPX 5.0.2 `--best`：识别格式 `win64/pe`，41,324,544 → 13,064,704 字节，`upx -t` 返回 `[OK]`。原始和 UPX 二进制的版本四标签、普通配置、三种禁用 outbound、两种 DNS 引用查询失败诊断均通过。复验入口为 `scripts/package-lite.sh`、`scripts/check-lite.sh`（UPX 使用 `--packed`）及 `python -I scripts/check-lite-dns.py <二进制>`。该结果不代表其他目标或历史工具链已验证；每次发行还必须通过 Windows runner 对 CI 定制工具链产物的原生冒烟。

不带排除标签的源码构建，以及 Makefile、Nix 的默认行为仍沿用上游。

## CI 与发行

普通提交和 PR 执行验证；版本 `v*` Git tag 触发完整矩阵与正式发行。手动运行 Build workflow 可用输入版本创建 prerelease，构建当前选择的 ref，不重写 Alpha/Meta 分支。两种发行使用相同 Lite 档案及变体规则。版本号和 Git tag 继续对应上游。

发布前检查每个目标必需的归档与系统包；准入 UPX 处理失败或必需文件缺失都会阻止发布。Windows 原生 runner 对非 UPX 和 UPX 两种变体进行版本及配置检查。交叉编译目标检查元数据与归档，不将跨平台构建成功视为原生运行成功。
