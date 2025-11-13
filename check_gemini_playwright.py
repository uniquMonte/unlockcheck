#!/usr/bin/env python3
"""
Gemini 地区限制检测 - Playwright 版本
使用无头浏览器执行 JavaScript 来检测动态加载的地区限制信息

安装依赖:
    pip install playwright
    playwright install chromium

或使用 docker:
    docker run -it --rm mcr.microsoft.com/playwright/python:v1.40.0-jammy python3
"""

import sys
import asyncio
import re

try:
    from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout
except ImportError:
    print("错误: 未安装 playwright")
    print("请运行: pip install playwright && playwright install chromium")
    sys.exit(1)


async def check_gemini_with_browser():
    """使用 Playwright 检测 Gemini 可用性"""

    print("=" * 60)
    print("Gemini 浏览器检测 (Playwright)")
    print("=" * 60)
    print()

    result = {
        "status": "unknown",
        "detail": "检测失败",
        "evidence": []
    }

    async with async_playwright() as p:
        print("【步骤 1】启动无头浏览器...")
        browser = await p.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-setuid-sandbox']
        )

        context = await browser.new_context(
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            viewport={'width': 1920, 'height': 1080}
        )

        page = await context.new_page()

        # 监听所有网络请求
        blocked_requests = []

        async def handle_response(response):
            """监听响应"""
            url = response.url
            status = response.status

            # 检查关键 API 请求
            if status == 403:
                blocked_requests.append({
                    'url': url,
                    'status': status
                })
                print(f"  ⚠ 检测到 403: {url[:80]}...")

        page.on("response", handle_response)

        print("✓ 浏览器已启动")
        print()

        print("【步骤 2】访问 Gemini 主页...")
        try:
            response = await page.goto(
                "https://gemini.google.com/",
                wait_until="networkidle",
                timeout=30000
            )

            print(f"  HTTP 状态码: {response.status}")
            print(f"  最终 URL: {page.url}")
            print()

        except PlaywrightTimeout:
            print("  ⚠ 页面加载超时")
            result["status"] = "error"
            result["detail"] = "页面加载超时"
            await browser.close()
            return result

        print("【步骤 3】等待 JavaScript 执行...")
        # 等待页面完全加载，JavaScript 完成执行
        await asyncio.sleep(3)
        print("✓ 等待完成")
        print()

        print("【步骤 4】检查页面内容...")

        # 获取页面文本内容
        body_text = await page.text_content('body')

        # 检查地区限制关键词
        restriction_patterns = [
            r"isn't currently supported in your country",
            r"not currently supported in your country",
            r"not available in your country",
            r"not supported in your region",
            r"unavailable in your country",
            r"Stay tuned",
        ]

        found_restriction = False
        for pattern in restriction_patterns:
            if re.search(pattern, body_text, re.IGNORECASE):
                print(f"  ✗ 找到限制消息: '{pattern}'")
                result["evidence"].append(f"页面包含: {pattern}")
                found_restriction = True

        if found_restriction:
            result["status"] = "failed"
            result["detail"] = "该地区不支持"

        # 检查成功标识
        success_patterns = [
            r"sign in",
            r"get started",
            r"chat",
            r"supercharge your",
        ]

        found_success = False
        for pattern in success_patterns:
            if re.search(pattern, body_text, re.IGNORECASE):
                if not found_restriction:  # 只有没有限制信息时才算成功
                    print(f"  ✓ 找到可用标识: '{pattern}'")
                    found_success = True

        if not found_restriction and found_success:
            result["status"] = "success"
            result["detail"] = "正常访问"
            result["evidence"].append("页面显示正常登录界面")

        print()

        # 检查被阻止的请求
        print("【步骤 5】检查被阻止的请求...")
        if blocked_requests:
            print(f"  发现 {len(blocked_requests)} 个 403 请求:")
            for req in blocked_requests[:5]:  # 只显示前5个
                print(f"    - {req['url'][:80]}")
            result["evidence"].append(f"发现 {len(blocked_requests)} 个 403 请求")

            # 如果有很多 403，可能是地区限制
            if len(blocked_requests) > 3 and not found_restriction:
                result["status"] = "failed"
                result["detail"] = "该地区不支持 (多个请求被阻止)"
        else:
            print("  ✓ 没有被阻止的请求")

        print()

        # 截图保存（可选）
        print("【步骤 6】保存截图...")
        screenshot_path = "/tmp/gemini_screenshot.png"
        await page.screenshot(path=screenshot_path)
        print(f"  ✓ 截图已保存: {screenshot_path}")
        print()

        # 保存页面 HTML
        print("【步骤 7】保存页面内容...")
        html_content = await page.content()
        html_path = "/tmp/gemini_playwright.html"
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        print(f"  ✓ HTML 已保存: {html_path}")
        print(f"     大小: {len(html_content)} 字节")
        print()

        await browser.close()

    return result


async def main():
    """主函数"""
    try:
        result = await check_gemini_with_browser()

        print("=" * 60)
        print("【最终结果】")
        print("=" * 60)
        print()
        print(f"状态: {result['status']}")
        print(f"详情: {result['detail']}")

        if result['evidence']:
            print()
            print("证据:")
            for evidence in result['evidence']:
                print(f"  - {evidence}")

        print()

        if result['status'] == "failed":
            print("🔴 Gemini: 该地区不支持")
            return 1
        elif result['status'] == "success":
            print("🟢 Gemini: 正常访问")
            return 0
        else:
            print("⚪ Gemini: 检测失败")
            return 2

    except Exception as e:
        print()
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        return 3


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
