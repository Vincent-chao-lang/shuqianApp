#
# claude_analyzer.py
# Claude Vision API 调用封装
#

import base64
import json
import time
from typing import List, Optional
from pathlib import Path
import httpx
from loguru import logger

from app.core.config import settings
from app.models.schemas import (
    ImageAnalysisResult,
    LayoutInfo,
    ColorScheme,
    DesignColor,
    Typography,
    StyleAttributes,
    MoodType,
    LayoutType,
    DecorativeElements,
)


class ClaudeAnalyzer:
    """Claude Vision API 分析器"""

    # 详细的分析提示词
    ANALYSIS_PROMPT = """你是一位专业的书签设计分析师。请仔细分析这张书签参考图片，提取以下设计元素：

## 1. 布局分析 (layout)
- 识别图片的构图方式：
  * left-right: 左图右文，图片和文字左右排列
  * top-bottom: 上图下文，图片在上文字在下
  * center-focused: 居中聚焦，主要元素居中对齐
  * mosaic-grid: 拼贴网格，多图拼接
  * full-bleed-image: 全出血图片，图片铺满整个区域
- 评估layout_type: 具体布局类型
- 评估confidence: 对该判断的置信度 (0-1)
- 提供description: 简短描述这个布局的特点

## 2. 配色分析 (colors)
提取完整的配色方案：
- primary: 主色调，最显眼的1-2个颜色
  * 每个颜色包含 hex (如 #F5F5DC) 和 name (如 米白)
- secondary: 辅助色，用于补充主色的1-2个颜色
- accent: 点缀色，用于强调的1个颜色
- neutral: 中性色，背景或文字用的1-2个颜色
- palette_name: 给这个配色方案起一个好听的名字
- mood: 描述这个配色传达的情绪/氛围
- harmony: 描述色彩和谐度（如：互补色、邻近色、单色系等）

## 3. 字体分析 (typography)
- primary_font: 主标题使用的字体风格（如：优雅衬线、现代无衬线、手写体等）
- body_font: 正文的字体风格
- font_pairs: 推荐的字体搭配（2-3对）
- text_color: 主要文字使用的颜色

## 4. 风格属性 (style_attributes)
- keywords: 提炼3-5个风格关键词（如：简约、复古、清新、科技感等）
- mood: 整体情绪，从以下选择：
  * 温暖治愈 - 温暖、舒适、治愈的感觉
  * 清新自然 - 清新、自然、有机的感觉
  * 专业简约 - 专业、简洁、商务的感觉
  * 活泼可爱 - 活泼、可爱、童趣的感觉
  * 优雅复古 - 优雅、复古、文艺的感觉
  * 现代时尚 - 现代、时尚、潮流的感觉
  * 艺术文艺 - 艺术、文艺、创意的感觉
- complexity: 复杂度等级 1-5
  * 1 = 极简，只有基本元素
  * 2 = 简约，少量装饰
  * 3 = 适中，标准设计
  * 4 = 丰富，较多元素
  * 5 = 复杂，多层次设计
- aesthetic_tags: 美学标签（如：几何、渐变、纹理、留白等）

## 5. 装饰元素 (decorative_elements)
- has_border: 是否有明显的边框装饰
- has_pattern: 是否有图案背景或纹理
- has_icon: 是否有图标或小插图
- suggested_elements: 建议可以添加的装饰元素列表

## 6. 改进建议 (suggestions)
提供3-5条具体的设计改进建议，让这个书签设计更出彩。

---

请以JSON格式返回分析结果，严格按照以下结构：

```json
{
  "layout": {
    "type": "布局类型(left-right/top-bottom/center-focused/mosaic-grid/full-bleed-image)",
    "confidence": 0.95,
    "description": "布局描述"
  },
  "colors": {
    "primary": [
      {"hex": "#F5F5DC", "name": "米白"},
      {"hex": "#8B7355", "name": "卡其色"}
    ],
    "secondary": [
      {"hex": "#D2691E", "name": "巧克力色"}
    ],
    "accent": [
      {"hex": "#FF6B6B", "name": "珊瑚红"}
    ],
    "neutral": [
      {"hex": "#333333", "name": "深灰"},
      {"hex": "#FFFFFF", "name": "纯白"}
    ],
    "palette_name": "温暖秋日",
    "mood": "温暖、舒适、自然",
    "harmony": "邻近色搭配，营造温馨氛围"
  },
  "typography": {
    "primary_font": "优雅衬线体",
    "body_font": "简洁无衬线体",
    "font_pairs": [
      "宋体 + 黑体",
      "楷体 + 思源黑体"
    ],
    "text_color": "#333333"
  },
  "style_attributes": {
    "keywords": ["简约", "优雅", "文艺"],
    "mood": "优雅复古",
    "complexity": 3,
    "aesthetic_tags": ["留白", "居中对齐", "精致边框"]
  },
  "decorative_elements": {
    "has_border": true,
    "has_pattern": false,
    "has_icon": true,
    "suggested_elements": ["细线边框", "小花朵图标", "渐变背景"]
  },
  "suggestions": [
    "建议增加一个精致的边框装饰",
    "可以考虑添加一些小巧的装饰元素",
    "颜色搭配很和谐，可以尝试添加渐变效果"
  ]
}
```

请开始分析："""

    def __init__(self):
        self.api_key = settings.ANTHROPIC_API_KEY
        self.model = settings.CLAUDE_MODEL
        self.max_tokens = settings.CLAUDE_MAX_TOKENS
        self.api_url = "https://api.anthropic.com/v1/messages"

    def _encode_image(self, image_path: str) -> str:
        """
        将图片编码为base64

        Args:
            image_path: 图片路径

        Returns:
            base64编码的图片字符串
        """
        with open(image_path, "rb") as f:
            image_data = f.read()
        return base64.b64encode(image_data).decode("utf-8")

    async def analyze_images(self, image_paths: List[str]) -> ImageAnalysisResult:
        """
        分析上传的参考图片

        Args:
            image_paths: 图片路径列表

        Returns:
            ImageAnalysisResult: 分析结果
        """
        logger.debug("🔍 [CLAUDE] analyze_images() called")
        logger.debug(f"   - Image count: {len(image_paths)}")

        if not self.api_key:
            logger.error("❌ [CLAUDE] API key not configured")
            raise ValueError("ANTHROPIC_API_KEY is not set in environment variables")

        logger.debug(f"   - Model: {self.model}")
        logger.debug(f"   - Max tokens: {self.max_tokens}")

        # 准备图片数据
        logger.debug("📸 [CLAUDE] Encoding images to base64...")
        images = []
        total_size = 0

        for idx, img_path in enumerate(image_paths):
            logger.debug(f"   - Encoding image {idx + 1}/{len(image_paths)}: {img_path}")

            encode_start = time.time()
            base64_image = self._encode_image(img_path)
            encode_time = time.time() - encode_start

            img_size = len(base64_image)
            total_size += img_size
            media_type = self._get_media_type(img_path)

            logger.debug(f"     * Media type: {media_type}")
            logger.debug(f"     * Base64 size: {img_size / 1024:.2f}KB")
            logger.debug(f"     * Encode time: {encode_time:.2f}s")

            images.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": base64_image
                }
            })

        logger.info(f"📸 [CLAUDE] All images encoded, total size: {total_size / 1024:.2f}KB")

        # 构建请求内容
        logger.debug("📝 [CLAUDE] Building request payload...")
        content = [
            {
                "type": "text",
                "text": self.ANALYSIS_PROMPT
            },
            *images
        ]

        # 构建请求头和请求体
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        }

        payload = {
            "model": self.model,
            "max_tokens": self.max_tokens,
            "messages": [
                {
                    "role": "user",
                    "content": content
                }
            ]
        }

        logger.debug(f"   - Payload size (approx): {len(json.dumps(payload)) / 1024:.2f}KB")

        try:
            # 发送API请求
            logger.info(f"🌐 [CLAUDE] Sending request to {self.api_url}")
            request_start = time.time()

            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    self.api_url,
                    headers=headers,
                    json=payload
                )

                request_time = time.time() - request_start
                logger.info(f"🌐 [CLAUDE] Response received in {request_time:.2f}s")
                logger.debug(f"   - Status: {response.status_code}")

                response.raise_for_status()

                # 解析响应
                parse_start = time.time()
                result = response.json()
                parse_time = time.time() - parse_start

                logger.debug(f"📦 [CLAUDE] Response parsed in {parse_time:.2f}s")

                # 提取使用量信息
                usage = result.get("usage", {})
                if usage:
                    logger.debug(f"💰 [CLAUDE] Token usage:")
                    logger.debug(f"   - Input tokens: {usage.get('input_tokens', 'N/A')}")
                    logger.debug(f"   - Output tokens: {usage.get('output_tokens', 'N/A')}")
                    logger.debug(f"   - Total tokens: {usage.get('input_tokens', 0) + usage.get('output_tokens', 0)}")

                # 提取分析结果
                content_block = result.get("content", [])
                if not content_block:
                    logger.error("❌ [CLAUDE] Empty response from API")
                    raise ValueError("Empty response from Claude API")

                analysis_text = content_block[0].get("text", "")
                logger.debug(f"📄 [CLAUDE] Analysis text length: {len(analysis_text)} chars")

                logger.debug("🔧 [CLAUDE] Parsing analysis result...")
                return self._parse_analysis_result(analysis_text)

        except httpx.HTTPStatusError as e:
            logger.error(f"❌ [CLAUDE] HTTP error: {e.response.status_code}")
            logger.error(f"❌ [CLAUDE] Response: {e.response.text}")

            # 如果是API密钥问题，返回mock数据用于测试
            if e.response.status_code == 403 or e.response.status_code == 401:
                logger.warning("⚠️ [CLAUDE] API密钥未配置或无效，返回mock数据")
                return self._get_mock_analysis_result()

            raise
        except Exception as e:
            logger.error(f"❌ [CLAUDE] Error: {str(e)}")
            logger.exception("❌ [CLAUDE] Full traceback:")
            raise

    def _get_mock_analysis_result(self) -> ImageAnalysisResult:
        """
        返回mock分析结果（用于API密钥无效时测试）

        Returns:
            ImageAnalysisResult: Mock分析结果
        """
        logger.info("🎭 [CLAUDE] Returning mock analysis result")

        return ImageAnalysisResult(
            layout=LayoutInfo(
                type=LayoutType.HORIZONTAL,
                confidence=0.9,
                description="左右分栏布局"
            ),
            colors=ColorScheme(
                primary=[
                    DesignColor(hex="#F5E6D3", name="米色")
                ],
                secondary=[
                    DesignColor(hex="#8B7355", name="棕褐")
                ],
                accent=[
                    DesignColor(hex="#D4A574", name="金棕")
                ],
                neutral=[
                    DesignColor(hex="#333333", name="深灰"),
                    DesignColor(hex="#FFFFFF", name="纯白")
                ],
                palette_name="温暖米色系",
                mood="温暖、舒适、自然",
                harmony="邻近色搭配，营造温馨氛围"
            ),
            typography=Typography(
                primary_font="优雅衬线体",
                body_font="简洁无衬线体",
                font_pairs=["宋体 + 黑体", "楷体 + 思源黑体"],
                text_color="#333333"
            ),
            style_attributes=StyleAttributes(
                keywords=["简约", "优雅", "文艺"],
                mood=MoodType.WARM,
                complexity=3,
                aesthetic_tags=["留白", "居中对齐", "精致边框"]
            ),
            decorative_elements=DecorativeElements(
                has_border=True,
                has_pattern=False,
                has_icon=True,
                suggested_elements=["细线边框", "小花朵图标", "渐变背景"]
            ),
            suggestions=[
                "建议增加一个精致的边框装饰",
                "可以考虑添加一些小巧的装饰元素",
                "颜色搭配很和谐，可以尝试添加渐变效果"
            ],
            raw_analysis="Mock analysis result for testing"
        )

    def _parse_analysis_result(self, analysis_text: str) -> ImageAnalysisResult:
        """
        解析Claude返回的分析结果

        Args:
            analysis_text: Claude返回的JSON文本

        Returns:
            ImageAnalysisResult: 解析后的分析结果
        """
        logger.debug("🔧 [CLAUDE] _parse_analysis_result() called")
        parse_start = time.time()

        try:
            # 提取JSON部分（Claude可能在JSON前后添加文字）
            json_start = analysis_text.find("{")
            json_end = analysis_text.rfind("}") + 1

            if json_start == -1 or json_end == 0:
                logger.error("❌ [CLAUDE] No JSON found in response")
                raise ValueError("No JSON found in Claude response")

            json_str = analysis_text[json_start:json_end]
            logger.debug(f"   - Extracted JSON: {json_start} -> {json_end}")
            logger.debug(f"   - JSON length: {len(json_str)} chars")

            data = json.loads(json_str)
            logger.debug("   - JSON parsed successfully")

            # 解析layout
            layout_data = data.get("layout", {})
            layout = LayoutInfo(
                type=LayoutType(layout_data.get("type", "center-focused")),
                confidence=layout_data.get("confidence", 0.8),
                description=layout_data.get("description", "")
            )
            logger.debug(f"   - Layout: {layout.type.value} (confidence: {layout.confidence})")

            # 解析colors
            colors_data = data.get("colors", {})
            colors = ColorScheme(
                primary=[
                    DesignColor(**c) for c in colors_data.get("primary", [])
                ],
                secondary=[
                    DesignColor(**c) for c in colors_data.get("secondary", [])
                ],
                accent=[
                    DesignColor(**c) for c in colors_data.get("accent", [])
                ],
                neutral=[
                    DesignColor(**c) for c in colors_data.get("neutral", [])
                ],
                palette_name=colors_data.get("palette_name", "未命名配色"),
                mood=colors_data.get("mood", ""),
                harmony=colors_data.get("harmony", "")
            )
            logger.debug(f"   - Palette: {colors.palette_name}")
            logger.debug(f"   - Colors: {len(colors.primary)} primary, {len(colors.secondary)} secondary, {len(colors.accent)} accent")

            # 解析typography
            typo_data = data.get("typography", {})
            typography = Typography(
                primary_font=typo_data.get("primary_font", ""),
                body_font=typo_data.get("body_font", ""),
                font_pairs=typo_data.get("font_pairs", []),
                text_color=typo_data.get("text_color", "#000000")
            )
            logger.debug(f"   - Font: {typography.primary_font} + {typography.body_font}")

            # 解析style_attributes
            style_data = data.get("style_attributes", {})
            style_attributes = StyleAttributes(
                keywords=style_data.get("keywords", []),
                mood=MoodType(style_data.get("mood", MoodType.WARM)),
                complexity=style_data.get("complexity", 3),
                aesthetic_tags=style_data.get("aesthetic_tags", [])
            )
            logger.debug(f"   - Mood: {style_attributes.mood.value}")
            logger.debug(f"   - Complexity: {style_attributes.complexity}")

            # 解析decorative_elements
            deco_data = data.get("decorative_elements", {})
            decorative_elements = DecorativeElements(
                has_border=deco_data.get("has_border", False),
                has_pattern=deco_data.get("has_pattern", False),
                has_icon=deco_data.get("has_icon", False),
                suggested_elements=deco_data.get("suggested_elements", [])
            )

            # 构建结果
            result = ImageAnalysisResult(
                layout=layout,
                colors=colors,
                typography=typography,
                style_attributes=style_attributes,
                decorative_elements=decorative_elements,
                suggestions=data.get("suggestions", []),
                raw_analysis=analysis_text
            )

            parse_time = time.time() - parse_start
            logger.info(f"✅ [CLAUDE] Result parsed in {parse_time:.2f}s")
            logger.info(f"✅ [CLAUDE] Final palette: {result.colors.palette_name}")
            return result

        except json.JSONDecodeError as e:
            logger.error(f"❌ [CLAUDE] JSON decode error: {e}")
            logger.error(f"❌ [CLAUDE] Raw response: {analysis_text[:500]}...")
            raise ValueError(f"Invalid JSON response from Claude: {str(e)}")
        except Exception as e:
            logger.error(f"❌ [CLAUDE] Parse error: {str(e)}")
            logger.exception("❌ [CLAUDE] Full traceback:")
            raise

    def _get_media_type(self, image_path: str) -> str:
        """
        根据文件扩展名获取媒体类型

        Args:
            image_path: 图片路径

        Returns:
            媒体类型字符串
        """
        ext = Path(image_path).suffix.lower()
        mime_types = {
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".png": "image/png",
            ".webp": "image/webp",
            ".gif": "image/gif"
        }
        return mime_types.get(ext, "image/jpeg")


# 全局实例
claude_analyzer = ClaudeAnalyzer()
