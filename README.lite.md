# Mihomo Lite（HAMAN23333/mihomo）

本 fork 的 Lite 发行系列固定排除 Tailscale、ZeroTier 和 EasyTier，并为每个归档目标提供两种能力配置：

| 能力配置 | Go build tags | 资产名 | 适用场景 |
| --- | --- | --- | --- |
| gVisor（兼容默认） | `with_gvisor no_tailscale no_zerotier no_easytier` | `mihomo-lite-<OS>-<目标>-<版本>` | 需要 gVisor，或希望沿用既有下载地址 |
| no-GVisor | `no_tailscale no_zerotier no_easytier` | `mihomo-lite-<OS>-<目标>-no-gvisor-<版本>` | 确认不使用 gVisor 能力，希望选择不链接其实现的二进制 |

Windows 资产使用 `.zip`，其他目标使用 `.gz`。归档内可执行文件采用相同的配置限定名，但不含版本。未限定名称始终代表 gVisor 配置，因此现有下载 URL 保持兼容。

Tailscale、ZeroTier、EasyTier outbound 在两种配置中均被禁用，配置使用它们会明确报错。Tailscale 和 EasyTier 的 DNS 引用可能在查询时才失败。no-GVisor 配置仍保留其他 TUN 能力；本文只承诺构建能力和链接边界，不作速度、延迟或内存方面的性能承诺。

所有目标均提供标准打包形式。通过验证的目标还提供名称带 `upx` 的 UPX 打包形式：

- gVisor：`mihomo-lite-<OS>-<目标>-upx-<版本>`
- no-GVisor：`mihomo-lite-<OS>-<目标>-no-gvisor-upx-<版本>`

UPX 只是同一能力配置的可执行文件副本经过压缩，不改变功能边界。初始发布 UPX 准入目标仍只有 `windows-amd64-v1`；新增目标必须补充格式支持、`upx -t` 和适用的原生运行证据。

DEB、RPM、Pacman 系统包和 Docker 镜像继续使用标准打包形式的 gVisor 配置。命令、容器内程序和系统包名仍为 `mihomo`。源码、vendor、工具链与校验和资产继续保留；Go module 文件中出现相关依赖不代表最终二进制链接它们。

## 本地构建

安装 Go 后，在 Git Bash 或 Bash 中运行：

```bash
bash build-local.sh
```

默认同时生成 gVisor 与 no-GVisor 配置，输出位于 `bin/local/`，保留 Windows amd64-v3、Linux amd64-v3、Linux arm64 三个本地目标。amd64-v3 需要支持对应指令集的 CPU。

也可以只构建一种能力配置：

```bash
bash build-local.sh --profile gvisor
```

```bash
bash build-local.sh --profile no-gvisor
```

`--profile` 可取 `gvisor`、`no-gvisor` 或 `both`，默认是 `both`。若本地目标已进入 `scripts/upx-targets.txt` 白名单，可附加 `--upx`；参数顺序不限：

```bash
bash build-local.sh --profile both --upx
```

当前三个本地目标均未进入 UPX 白名单，因此脚本会明确跳过它们，不会把本地尝试当作发布准入证据。发布使用的 UPX 版本与归档 SHA-256 固定在 `scripts/install-upx.sh`。

构建后，脚本通过最终二进制元数据验证三个 Lite 排除标签和 SDK 链接边界。gVisor 配置必须包含 `with_gvisor`；no-GVisor 配置必须不包含该标签，且不得链接 `github.com/metacubex/gvisor` 实现。该要求只针对最终可执行文件，不要求从源码、module 文件、缓存或 vendor 中删除依赖材料。

不带 Lite 排除标签的源码构建，以及 Makefile、Nix 的默认行为仍沿用上游。

## CI 与发行

普通提交和 PR 执行验证；版本 `v*` Git tag 触发完整矩阵与正式发行。手动运行 Build workflow 可用输入版本创建 prerelease，构建当前选择的 ref，不重写 Alpha/Meta 分支。两种发行使用相同能力配置和打包规则，版本号和 Git tag 继续对应上游。

现有 90 个目标任务各自顺序构建两种能力配置，不复制目标矩阵。发布前检查每个目标的两种标准归档，以及准入目标的两种 UPX 归档；任一必需文件缺失都会阻止发布。Windows 原生 runner 对 `windows-amd64-v1` 的四个可执行文件执行完整性和启动验证，其中 gVisor 配置保留普通配置、三种禁用 outbound 和两种 DNS 引用检查；no-GVisor 的能力边界由原始二进制静态验证，不新增 `gvisor`/`mixed` 运行时报错测试。
