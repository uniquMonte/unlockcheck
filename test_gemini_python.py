#!/usr/bin/env python3
import requests

TIMEOUT = 5
session = requests.Session()
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
})

api_result = None
web_result = None
static_result = None
studio_result = None

print("=" * 60)
print("Gemini Python 检测测试")
print("=" * 60)
print()

# Step 1: API
print("【步骤 1】检测 API 端点...")
try:
    api_response = session.get(
        "https://generativelanguage.googleapis.com/v1beta/models",
        timeout=TIMEOUT,
        headers={'Content-Type': 'application/json'}
    )

    print(f"  HTTP 状态码: {api_response.status_code}")
    print(f"  响应内容 (前200字符): {api_response.text[:200]}")

    if api_response.status_code == 401 or api_response.status_code == 400:
        api_result = ("success", "Normal Access")
        print("  → 判断: success")
    elif api_response.status_code == 403:
        try:
            error_data = api_response.json()
            print(f"  JSON 解析成功: {error_data}")
            if 'error' in error_data:
                error_info = error_data['error']
                error_status = error_info.get('status', '')
                error_msg = error_info.get('message', '').lower()

                if error_status == 'PERMISSION_DENIED':
                    if 'api key' in error_msg or 'unregistered callers' in error_msg or 'established identity' in error_msg:
                        api_result = ("success", "Normal Access")
                        print("  → 判断: success (PERMISSION_DENIED + api key)")
                    else:
                        api_result = ("failed", "Access Denied")
                        print("  → 判断: failed (PERMISSION_DENIED 无 api key)")
                elif any(keyword in error_msg for keyword in ['country', 'region', 'territory', 'not available', 'not supported']):
                    api_result = ("failed", "Region Restricted")
                    print("  → 判断: region_restricted (地区关键词)")
                else:
                    api_result = ("failed", "Access Denied")
                    print("  → 判断: failed (其他错误)")
            else:
                api_result = ("failed", "Access Denied")
                print("  → 判断: failed (无 error 字段)")
        except Exception as e:
            # 403 but not JSON response = likely region restriction
            api_result = ("failed", "Region Restricted")
            print(f"  JSON 解析失败: {e}")
            print("  → 判断: region_restricted (非 JSON 响应)")
    elif api_response.status_code == 451:
        api_result = ("failed", "Region Restricted")
        print("  → 判断: region_restricted (HTTP 451)")
except Exception as e:
    print(f"  异常: {e}")

print()

# Step 2: Web
print("【步骤 2】检测主域名...")
try:
    web_response = session.get(
        "https://gemini.google.com/",
        timeout=TIMEOUT,
        allow_redirects=True
    )

    print(f"  HTTP 状态码: {web_response.status_code}")
    print(f"  响应内容 (前200字符): {web_response.text[:200]}")

    content_lower = web_response.text.lower()

    if web_response.status_code == 403:
        if "access denied" in content_lower:
            web_result = ("failed", "Region Restricted")
            print("  → 判断: region_restricted (403 + access denied)")
        else:
            web_result = ("failed", "Access Denied")
            print("  → 判断: failed (403 无 access denied)")
    elif "supported in your country" in content_lower or "not available in your country" in content_lower:
        web_result = ("failed", "Region Restricted")
        print("  → 判断: region_restricted (地区消息)")
    elif web_response.status_code == 200:
        if any(keyword in content_lower for keyword in ["sign in", "get started", "continue with google", "chat with gemini"]):
            web_result = ("success", "Normal Access")
            print("  → 判断: success (200 + 登录界面)")
        else:
            print("  → 判断: unknown (200 但无登录界面)")
except Exception as e:
    print(f"  异常: {e}")

print()

# Step 3: Static
print("【步骤 3】检测静态资源...")
region_confirmed = (
    (api_result and api_result[0] == "failed" and "Region Restricted" in api_result[1]) or
    (web_result and web_result[0] == "failed" and "Region Restricted" in web_result[1])
)

if region_confirmed:
    print("  已确认地区限制，跳过")
else:
    try:
        static_response = session.get(
            "https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg",
            timeout=TIMEOUT
        )
        print(f"  HTTP 状态码: {static_response.status_code}")
        if static_response.status_code == 403:
            static_result = ("failed", "Region Restricted")
            print("  → 判断: region_restricted")
        elif static_response.status_code == 200:
            static_result = ("success", "Normal Access")
            print("  → 判断: success")
    except Exception as e:
        print(f"  异常: {e}")

print()

# Step 4: Studio
print("【步骤 4】检测 AI Studio...")
region_confirmed = (
    (api_result and api_result[0] == "failed" and "Region Restricted" in api_result[1]) or
    (web_result and web_result[0] == "failed" and "Region Restricted" in web_result[1]) or
    (static_result and static_result[0] == "failed" and "Region Restricted" in static_result[1])
)

if region_confirmed:
    print("  已确认地区限制，跳过")
else:
    try:
        studio_response = session.get(
            "https://aistudio.google.com/app/prompts/new_chat",
            timeout=TIMEOUT,
            allow_redirects=False
        )
        print(f"  HTTP 状态码: {studio_response.status_code}")
        if studio_response.status_code == 403:
            studio_result = ("failed", "Region Restricted")
            print("  → 判断: region_restricted")
        elif studio_response.status_code in [200, 302]:
            studio_result = ("success", "Normal Access")
            print("  → 判断: success")
    except Exception as e:
        print(f"  异常: {e}")

print()
print("=" * 60)
print("【最终决策】")
print("=" * 60)
print(f"api_result: {api_result}")
print(f"web_result: {web_result}")
print(f"static_result: {static_result}")
print(f"studio_result: {studio_result}")
print()

# Decision
if api_result and api_result[0] == "failed" and "Region Restricted" in api_result[1]:
    print("🔴 最终结果: Region Restricted (from API)")
elif web_result and web_result[0] == "failed":
    print(f"🔴 最终结果: Region Restricted (from Web: {web_result[1]})")
elif static_result and static_result[0] == "failed":
    print(f"🔴 最终结果: Region Restricted (from Static: {static_result[1]})")
elif studio_result and studio_result[0] == "failed":
    print(f"🔴 最终结果: Region Restricted (from Studio: {studio_result[1]})")
elif api_result and api_result[0] == "success":
    print("🟢 最终结果: Normal Access (from API)")
elif web_result and web_result[0] == "success":
    print("🟢 最终结果: Normal Access (from Web)")
elif static_result and static_result[0] == "success":
    print("🟢 最终结果: Normal Access (from Static)")
elif studio_result and studio_result[0] == "success":
    print("🟢 最终结果: Normal Access (from Studio)")
elif api_result and api_result[0] == "failed":
    print("🔴 最终结果: Access Denied")
else:
    print("⚪ 最终结果: Detection Failed")
