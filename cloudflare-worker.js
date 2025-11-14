// UnlockCheck 统计服务 - Cloudflare Worker
// 用于统计脚本使用情况：今日IP检测量、总检测量

export default {
  async fetch(request, env) {
    // 允许 CORS
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // 处理 OPTIONS 请求
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      const url = new URL(request.url);

      // 获取客户端IP的哈希值（用于去重，不存储原始IP）
      const clientIP = request.headers.get('CF-Connecting-IP') || 'unknown';
      const ipHash = await hashIP(clientIP);

      // 获取今天的日期（UTC）
      const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

      // KV 键名
      const TOTAL_KEY = 'total_count';
      const TODAY_KEY = `daily_ips_${today}`;
      const TODAY_COUNT_KEY = `daily_count_${today}`;

      if (request.method === 'POST' && url.pathname === '/report') {
        // 记录检测

        // 1. 增加总检测量
        let totalCount = parseInt(await env.STATS.get(TOTAL_KEY) || '0');
        totalCount++;
        await env.STATS.put(TOTAL_KEY, totalCount.toString());

        // 2. 检查今日IP是否已存在
        const todayIPs = await env.STATS.get(TODAY_KEY) || '';
        const ipSet = new Set(todayIPs.split(',').filter(ip => ip));

        const isNewIP = !ipSet.has(ipHash);
        if (isNewIP) {
          // 新IP，添加到集合
          ipSet.add(ipHash);
          await env.STATS.put(TODAY_KEY, Array.from(ipSet).join(','), {
            expirationTtl: 86400 * 2, // 保留2天，防止时区问题
          });
        }

        // 3. 增加今日检测量
        let todayCount = parseInt(await env.STATS.get(TODAY_COUNT_KEY) || '0');
        todayCount++;
        await env.STATS.put(TODAY_COUNT_KEY, todayCount.toString(), {
          expirationTtl: 86400 * 2,
        });

        return new Response(JSON.stringify({
          success: true,
          message: 'Reported successfully'
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      if (request.method === 'GET' && url.pathname === '/stats') {
        // 获取统计数据

        const totalCount = parseInt(await env.STATS.get(TOTAL_KEY) || '0');
        const todayIPs = await env.STATS.get(TODAY_KEY) || '';
        const todayUniqueCount = todayIPs.split(',').filter(ip => ip).length;

        return new Response(JSON.stringify({
          today_unique_ips: todayUniqueCount,
          total_detections: totalCount,
          date: today
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // 默认返回使用说明
      return new Response(JSON.stringify({
        name: 'UnlockCheck Statistics API',
        endpoints: {
          'POST /report': 'Report a detection (increments counters)',
          'GET /stats': 'Get current statistics'
        },
        github: 'https://github.com/uniquMonte/unlockcheck'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });

    } catch (error) {
      return new Response(JSON.stringify({
        success: false,
        error: error.message
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  }
};

// 使用 SHA-256 对 IP 进行哈希，保护隐私
async function hashIP(ip) {
  const msgBuffer = new TextEncoder().encode(ip);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  return hashHex.substring(0, 16); // 只保留前16位
}
