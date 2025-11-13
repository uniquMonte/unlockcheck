# 贡献指南

感谢您对 StreamCheck 项目的关注！我们欢迎各种形式的贡献。

## 如何贡献

### 报告 Bug

如果您发现了 bug，请：

1. 检查 [Issues](https://github.com/yourusername/streamcheck/issues) 确认问题是否已被报告
2. 如果没有，创建新 Issue 并提供：
   - 清晰的标题和描述
   - 重现步骤
   - 预期行为和实际行为
   - 系统环境信息（操作系统、Python 版本等）
   - 相关的错误日志（使用 `--verbose` 模式）

### 提出新功能

如果您有新功能建议：

1. 先在 Issues 中讨论您的想法
2. 说明功能的用途和预期效果
3. 如果可能，提供实现思路

### 提交代码

#### 准备工作

1. Fork 本项目
2. 克隆您的 fork
```bash
git clone https://github.com/YOUR_USERNAME/streamcheck.git
cd streamcheck
```

3. 创建新分支
```bash
git checkout -b feature/your-feature-name
# 或
git checkout -b fix/your-bug-fix
```

#### 开发规范

**Python 代码**

- 遵循 PEP 8 代码风格
- 添加适当的注释和文档字符串
- 函数应该有类型提示
- 保持代码简洁易读

**Bash 代码**

- 使用 shellcheck 检查脚本
- 添加适当的注释
- 遵循 [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

**通用要求**

- 确保代码能在不同平台运行（Linux, macOS, Windows）
- 添加必要的错误处理
- 更新相关文档

#### 测试

在提交前，请测试您的更改：

```bash
# Python 版本
python streamcheck.py --verbose

# Bash 版本
./streamcheck.sh
```

#### 提交更改

1. 添加更改
```bash
git add .
```

2. 提交更改（使用清晰的提交信息）
```bash
git commit -m "Add: 新增 XXX 功能"
# 或
git commit -m "Fix: 修复 XXX 问题"
```

提交信息格式：
- `Add: 新增功能`
- `Fix: 修复 bug`
- `Update: 更新功能`
- `Docs: 文档更新`
- `Style: 代码格式调整`
- `Refactor: 代码重构`

3. 推送到您的 fork
```bash
git push origin feature/your-feature-name
```

4. 创建 Pull Request
   - 访问原项目页面
   - 点击 "New Pull Request"
   - 选择您的分支
   - 填写 PR 描述，说明：
     - 更改内容
     - 解决的问题
     - 测试情况

## 添加新平台检测

如果您想添加新的流媒体平台检测：

### Python 版本

1. 在 `StreamChecker` 类中添加新方法：

```python
def check_newplatform(self) -> Tuple[str, str, str]:
    """
    检测 NewPlatform 解锁情况
    返回: (状态, 区域, 详细信息)
    """
    self.log("检测 NewPlatform...", "debug")

    try:
        response = self.session.get(
            "https://www.newplatform.com/api/check",
            timeout=TIMEOUT
        )

        if response.status_code == 200:
            return "success", self.ip_info.get('country_code', 'Unknown'), "支持"
        elif response.status_code == 403:
            return "failed", "N/A", "不支持"

        return "error", "N/A", "检测失败"

    except Exception as e:
        self.log(f"NewPlatform 检测异常: {e}", "debug")
        return "error", "N/A", "检测失败"
```

2. 在 `run_all_checks` 方法的 `checks` 列表中添加：

```python
checks = [
    # ... 现有检测 ...
    ("NewPlatform", self.check_newplatform),
]
```

3. 在命令行参数中添加选项（如需要）

### Bash 版本

添加检测函数：

```bash
# 检测 NewPlatform
check_newplatform() {
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time $TIMEOUT \
        -A "$USER_AGENT" \
        "https://www.newplatform.com/" 2>/dev/null)

    if [ "$status_code" = "200" ]; then
        format_result "NewPlatform" "success" "$COUNTRY_CODE" "支持"
    elif [ "$status_code" = "403" ]; then
        format_result "NewPlatform" "failed" "N/A" "不支持"
    else
        format_result "NewPlatform" "error" "N/A" "检测失败"
    fi
}
```

然后在 `run_all_checks` 函数中调用它。

## 代码审查

所有 Pull Request 都会经过审查。审查者可能会：

- 提出修改建议
- 请求更多测试
- 讨论实现方式

请耐心等待反馈，并积极响应评论。

## 行为准则

- 尊重所有贡献者
- 欢迎建设性的批评和建议
- 专注于对项目最有利的方案
- 保持友好和专业的态度

## 许可证

提交代码即表示您同意将您的贡献以 MIT 许可证发布。

## 问题？

如有任何问题，请：

- 查看现有 Issues 和文档
- 创建新 Issue 提问
- 联系维护者

再次感谢您的贡献！
