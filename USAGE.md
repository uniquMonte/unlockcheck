# UnlockCheck 使用指南

## 快速开始

### Python 版本

1. **安装依赖**
```bash
pip install -r requirements.txt
```

2. **运行检测**
```bash
python unlockcheck.py
```

### Bash 版本

1. **添加执行权限**（首次使用）
```bash
chmod +x unlockcheck.sh
```

2. **运行检测**
```bash
./unlockcheck.sh
```

## 高级用法

### Python 版本选项

#### 检测单个服务
```bash
# 仅检测 Netflix
python unlockcheck.py --service netflix

# 仅检测 Disney+
python unlockcheck.py --service disney

# 仅检测 YouTube Premium
python unlockcheck.py --service youtube

# 仅检测 ChatGPT
python unlockcheck.py --service chatgpt

# 仅检测 Claude
python unlockcheck.py --service claude

# 仅检测 TikTok
python unlockcheck.py --service tiktok
```

#### 详细模式
```bash
# 显示详细的调试信息
python unlockcheck.py --verbose

# 或使用短选项
python unlockcheck.py -v
```

#### IPv6 检测
```bash
# 使用 IPv6 进行检测
python unlockcheck.py --ipv6
```

#### 组合选项
```bash
# 详细模式 + 单个服务
python unlockcheck.py --verbose --service netflix

# IPv6 + 详细模式
python unlockcheck.py --ipv6 --verbose
```

### Bash 版本选项

#### 快速模式
```bash
# 不等待延迟，快速完成所有检测
./unlockcheck.sh --fast
```

#### 查看帮助
```bash
./unlockcheck.sh --help
```

#### 查看版本
```bash
./unlockcheck.sh --version
```

## 输出说明

### 状态图标

- `[✓]` (绿色) - 完全支持/解锁
- `[✗]` (红色) - 不支持/受限
- `[◐]` (黄色) - 部分支持
- `[?]` (紫色) - 检测失败/未知

### 检测结果示例

```
[✓] Netflix         : 完整解锁 (区域: US)
```
表示 Netflix 完全解锁，当前区域为美国。

```
[✗] ChatGPT         : 区域受限
```
表示 ChatGPT 在当前区域不可用。

```
[◐] Netflix         : 仅自制剧 (区域: CN)
```
表示 Netflix 仅支持自制剧内容。

## 常见问题

### 1. 检测失败怎么办？

- 检查网络连接是否正常
- 确认防火墙或代理设置
- 使用 `--verbose` 模式查看详细错误信息

### 2. 检测结果不准确？

- 某些平台的检测基于 API 响应，可能存在误差
- 实际可用性还取决于：
  - 账号状态
  - 支付方式
  - 具体内容授权
- 建议多次检测确认结果

### 3. 如何在代理环境下使用？

Python 版本会自动使用系统代理设置，或设置环境变量：

```bash
# HTTP 代理
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"

# SOCKS5 代理
export HTTP_PROXY="socks5://127.0.0.1:1080"
export HTTPS_PROXY="socks5://127.0.0.1:1080"

# 然后运行检测
python unlockcheck.py
```

Bash 版本需要确保 curl 可以访问代理。

### 4. 为什么有些检测很慢？

- 网络延迟
- 某些平台的 API 响应较慢
- 可以使用 Bash 版本的 `--fast` 模式跳过延迟

### 5. 如何定期自动检测？

使用 cron 任务（Linux/Mac）：

```bash
# 编辑 crontab
crontab -e

# 每天上午 9 点运行检测，结果保存到文件
0 9 * * * /path/to/unlockcheck.py > /path/to/result.txt 2>&1
```

## 贡献

如果您发现检测不准确或有改进建议，欢迎：

1. 提交 Issue 描述问题
2. Fork 项目并提交 Pull Request
3. 分享使用经验和建议

## 技术细节

### 检测原理

1. **Netflix**: 访问特定原创内容页面，根据 HTTP 状态码判断
2. **Disney+**: 检测主页和 API 可访问性
3. **YouTube Premium**: 访问 Premium 页面
4. **ChatGPT**: 检测 OpenAI 服务主页
5. **Claude**: 检测 Anthropic 服务主页
6. **TikTok**: 检测主页访问和区域限制

### 隐私说明

- 本工具仅发送必要的 HTTP 请求
- 不收集或上传任何个人信息
- 所有检测在本地进行
- IP 信息通过公开 API 获取

## 更新日志

### v1.0 (2025-11-13)
- 初始版本发布
- 支持 6 个主流平台检测
- 提供 Python 和 Bash 两个版本
- 彩色终端输出
- 详细的地理位置信息
