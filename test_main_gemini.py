#!/usr/bin/env python3
import sys
sys.path.insert(0, '/home/user/unlockcheck')

from unlockcheck import UnlockChecker

print("测试主脚本中的 Gemini 检测...")
print("=" * 60)

checker = UnlockChecker()
status, region, detail = checker.check_gemini()

print()
print(f"返回结果:")
print(f"  status: {status}")
print(f"  region: {region}")
print(f"  detail: {detail}")
print()

if status == "failed":
    print("🔴 检测结果: 地区受限")
elif status == "success":
    print("🟢 检测结果: 正常访问")
else:
    print("⚪ 检测结果: 其他状态")
