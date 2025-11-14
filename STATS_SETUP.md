# UnlockCheck 统计功能部署指南

本文档介绍如何部署和配置 UnlockCheck 的使用统计功能。

## 功能说明

统计功能可以显示：
- **今日 IP 检测量**：今天有多少不同的 IP 使用了脚本（通过 IP 哈希去重）
- **总检测量**：脚本总共被运行的次数

显示效果：
```
📊 使用统计
今日IP检测量：560；总检测量：722846
感谢使用 UnlockCheck！
```

## 部署步骤

### 1. 创建 Cloudflare Worker

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 选择你的账户 > Workers & Pages
3. 点击 "Create Worker"
4. 复制 `cloudflare-worker.js` 的内容粘贴到编辑器
5. 点击 "Save and Deploy"
6. 记录 Worker 的 URL（例如：`https://unlockcheck-stats.your-subdomain.workers.dev`）

### 2. 创建 KV 命名空间

1. 在 Cloudflare Dashboard 中，进入 Workers & Pages > KV
2. 点击 "Create namespace"
3. 命名为 `STATS`（或其他你喜欢的名称）
4. 创建完成后，记录 Namespace ID

### 3. 绑定 KV 到 Worker

1. 回到你的 Worker 设置页面
2. 进入 "Settings" > "Variables"
3. 在 "KV Namespace Bindings" 部分，点击 "Add binding"
4. Variable name 填写：`STATS`
5. KV namespace 选择刚才创建的命名空间
6. 保存设置

### 4. 配置脚本

编辑 `unlockcheck.sh`，修改第 13 行：

```bash
STATS_API_URL="https://unlockcheck-stats.your-subdomain.workers.dev"
```

将 URL 替换为你的 Worker URL。

### 5. 测试

运行脚本测试统计功能：
```bash
bash unlockcheck.sh
```

检测完成后，应该会在底部看到统计信息。

## 隐私说明

- ✅ **不存储原始 IP**：使用 SHA-256 哈希后只保留前 16 位
- ✅ **数据自动过期**：每日数据在 2 天后自动删除
- ✅ **匿名统计**：只统计数量，不关联任何个人信息
- ✅ **可选功能**：将 `STATS_API_URL` 设为空即可禁用

## API 接口说明

### POST /report
上报一次检测（脚本自动调用）

### GET /stats
获取统计数据

返回示例：
```json
{
  "today_unique_ips": 560,
  "total_detections": 722846,
  "date": "2025-01-14"
}
```

## 故障排除

### 统计不显示

1. 检查 `STATS_API_URL` 是否正确配置
2. 手动访问 `https://your-worker-url/stats` 查看是否返回数据
3. 检查 Worker 日志是否有错误

### KV 绑定错误

确保：
- KV 命名空间已创建
- Variable name 必须是 `STATS`（与 Worker 代码中的 `env.STATS` 一致）
- 绑定已保存并重新部署 Worker

## 成本

Cloudflare Workers 免费套餐：
- ✅ 每天 100,000 次请求
- ✅ KV 存储免费（10GB）
- ✅ 完全满足个人项目需求

## 参考

- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [KV 存储文档](https://developers.cloudflare.com/kv/)
