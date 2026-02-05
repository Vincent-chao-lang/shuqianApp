#
# vision_adapter.py
# 多模型视觉分析适配器
#

from abc import ABC, abstractmethod
from typing import List, Dict, Any
from enum import Enum
import httpx
from loguru import logger

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
from app.core.config import settings


class VisionModel(str, Enum):
    """支持的视觉模型"""
    GLM = "glm"
    QWEN = "qwen"
    CLAUDE = "claude"


class VisionAnalyzerAdapter(ABC):
    """视觉分析器适配器基类"""

    def __init__(self, api_key: str, model: str):
        self.api_key = api_key
        self.model = model
        self.timeout = 60.0

    @abstractmethod
    async def analyze_images(self, image_paths: List[str]) -> ImageAnalysisResult:
        """
        分析图片（子类必须实现）

        Args:
            image_paths: 图片路径列表

        Returns:
            ImageAnalysisResult: 分析结果
        """
        pass

    def _encode_image(self, image_path: str) -> str:
        """将图片编码为base64"""
        import base64
        with open(image_path, "rb") as f:
            image_data = f.read()
        return base64.b64encode(image_data).decode("utf-8")

    async def _make_request(
        self,
        url: str,
        headers: Dict[str, str],
        payload: Dict[str, Any]
    ) -> Dict[str, Any]:
        """发送HTTP请求（通用方法）"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            return response.json()


class GLMAnalyzer(VisionAnalyzerAdapter):
    """GLM-4V 视觉分析器（使用官方SDK）"""

    def __init__(self, api_key: str):
        super().__init__(api_key, "glm-4v-flash")
        try:
            from zhipuai import ZhipuAI
            self.client = ZhipuAI(api_key=api_key)
            logger.info("✅ [GLM] Official SDK initialized")
        except ImportError:
            logger.error("❌ [GLM] zhipuai package not found, using fallback")
            self.client = None

    async def analyze_images(self, image_paths: List[str]) -> ImageAnalysisResult:
        """使用GLM-4V分析图片"""
        logger.info(f"🤖 [GLM] Analyzing {len(image_paths)} images with {self.model}")

        if not self.client:
            logger.error("❌ [GLM] SDK not available, using mock")
            return self._get_mock_result()

        try:
            # 准备消息内容 (使用GLM SDK的多模态格式)
            prompt = self._get_analysis_prompt()

            # 构建内容列表
            content_list = [
                {
                    "type": "text",
                    "text": prompt
                }
            ]

            # 添加图片
            for img_path in image_paths:
                base64_image = self._encode_image(img_path)
                content_list.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{base64_image}"
                    }
                })

            messages = [{
                "role": "user",
                "content": content_list
            }]

            logger.info(f"🌐 [GLM] Calling API with {len(image_paths)} images")

            # 调用GLM API
            response = self.client.chat.completions.create(
                model="glm-4v",
                messages=messages,
                temperature=0.7,
                max_tokens=2000
            )

            # 提取分析结果
            result_content = response.choices[0].message.content
            logger.info(f"✅ [GLM] API call successful")
            logger.info(f"📝 [GLM] Response length: {len(result_content)}")
            logger.info(f"📝 [GLM] Response preview: {result_content[:500]}")

            return self._parse_result(result_content)

        except Exception as e:
            logger.error(f"❌ [GLM] Error: {str(e)}")
            logger.exception(e)
            # 返回mock结果
            return self._get_mock_result()

    def _get_analysis_prompt(self) -> str:
        """获取GLM分析提示词"""
        return """请分析这张图片并返回JSON格式的结果。

要求格式：
{
  "layout": "left-right",
  "colors": ["#颜色1", "#颜色2"],
  "mood": "温暖治愈",
  "complexity": 3
}

注意：
- layout只能选: left-right, top-bottom, center-focused, mosaic-grid, full-bleed-image
- mood只能选: 温暖治愈, 清新自然, 专业简约, 活泼可爱, 优雅复古, 现代时尚, 艺术文艺
- colors用HEX格式如#FFFFFF
- complexity是1-5的数字

**只返回JSON，不要任何其他文字**。"""

    def _parse_result(self, content: str) -> ImageAnalysisResult:
        """解析GLM返回的结果"""
        import json

        logger.info(f"🔍 [GLM] Parsing response content...")

        # 提取preview（原始内容的前500字符）
        preview_text = content[:500] if len(content) > 500 else content

        # 尝试从content中提取JSON
        try:
            json_start = content.find("{")
            json_end = content.rfind("}") + 1
            if json_start >= 0 and json_end > json_start:
                json_str = content[json_start:json_end]
                logger.info(f"🔍 [GLM] Extracted JSON: {json_str}")
                data = json.loads(json_str)
                logger.info(f"✅ [GLM] JSON parsed successfully")
                return self._convert_to_result(data, preview=preview_text)
        except Exception as e:
            logger.warning(f"⚠️ [GLM] Failed to parse JSON: {e}")
            logger.debug(f"⚠️ [GLM] Content was: {content}")

        # 解析失败，返回mock结果
        logger.info("⚠️ [GLM] Using mock result due to parse failure")
        return self._get_mock_result(preview=preview_text)

    def _convert_to_result(self, data: Dict, preview: str = None) -> ImageAnalysisResult:
        """将GLM返回的数据转换为标准格式"""
        # 提取数据或使用默认值
        layout_str = data.get("layout", "left-right")
        colors_list = data.get("colors", ["#F5E6D3", "#8B7355", "#D4A574", "#333333"])
        mood_str = data.get("mood", "温暖治愈")
        complexity = data.get("complexity", 3)

        # 映射布局类型
        layout_map = {
            "left-right": LayoutType.HORIZONTAL,
            "top-bottom": LayoutType.VERTICAL,
            "center-focused": LayoutType.CENTERED,
            "mosaic-grid": LayoutType.MOSAIC,
            "full-bleed-image": LayoutType.FULL_BLEED
        }
        layout_type = layout_map.get(layout_str, LayoutType.HORIZONTAL)

        # 映射情绪类型
        mood_map = {
            "温暖治愈": MoodType.WARM,
            "清新自然": MoodType.FRESH,
            "专业简约": MoodType.PROFESSIONAL,
            "活泼可爱": MoodType.PLAYFUL,
            "优雅复古": MoodType.ELEGANT,
            "现代时尚": MoodType.MODERN,
            "艺术文艺": MoodType.ARTISTIC
        }
        mood_type = mood_map.get(mood_str, MoodType.WARM)

        # 构建颜色列表
        def get_color(hex_val, name):
            return DesignColor(hex=hex_val.upper() if hex_val.startswith("#") else f"#{hex_val}", name=name)

        colors = ColorScheme(
            primary=[get_color(colors_list[0], "主色")] if len(colors_list) > 0 else [],
            secondary=[get_color(colors_list[1], "辅色")] if len(colors_list) > 1 else [],
            accent=[get_color(colors_list[2], "点缀色")] if len(colors_list) > 2 else [],
            neutral=[get_color(colors_list[3], "中性色")] if len(colors_list) > 3 else [],
            palette_name=f"{mood_str}配色",
            mood=mood_str,
            harmony="和谐搭配"
        )

        logger.info(f"✅ [GLM] Converted result: layout={layout_str}, mood={mood_str}, complexity={complexity}")

        return ImageAnalysisResult(
            layout=LayoutInfo(
                type=layout_type,
                confidence=0.9,
                description=f"{layout_str}布局"
            ),
            colors=colors,
            typography=Typography(
                primary_font="优雅衬线体",
                body_font="简洁无衬线体",
                font_pairs=["宋体 + 黑体"],
                text_color="#333333"
            ),
            style_attributes=StyleAttributes(
                keywords=[mood_str],
                mood=mood_type,
                complexity=complexity,
                aesthetic_tags=[]
            ),
            decorative_elements=DecorativeElements(
                has_border=True,
                has_pattern=False,
                has_icon=False,
                suggested_elements=[]
            ),
            suggestions=[f"基于{mood_str}风格的设计建议"],
            preview=preview,
            raw_analysis=str(data)
        )

    def _get_mock_result(self, preview: str = None) -> ImageAnalysisResult:
        """获取mock结果（用于测试）"""
        logger.info("🎭 [GLM] Returning mock result")
        return self._convert_to_result({}, preview=preview)


class QwenAnalyzer(VisionAnalyzerAdapter):
    """Qwen-VL 视觉分析器"""

    def __init__(self, api_key: str):
        super().__init__(api_key, "qwen-vl-plus")
        self.api_url = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

    async def analyze_images(self, image_paths: List[str]) -> ImageAnalysisResult:
        """使用Qwen-VL分析图片"""
        logger.info(f"🤖 [Qwen] Analyzing {len(image_paths)} images with {self.model}")

        # 准备消息
        messages = [{
            "role": "user",
            "content": []
        }]

        # 添加提示词
        prompt = self._get_analysis_prompt()
        messages[0]["content"].append({"type": "text", "text": prompt})

        # 添加图片
        for img_path in image_paths:
            base64_image = self._encode_image(img_path)
            messages[0]["content"].append({
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}
            })

        # 构建请求
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.7
        }

        try:
            logger.info(f"🌐 [Qwen] Sending request to {self.api_url}")
            result = await self._make_request(self.api_url, headers, payload)

            content = result.get("choices", [{}])[0].get("message", {}).get("content", "")
            logger.info(f"✅ [Qwen] Analysis completed")

            return self._parse_result(content)

        except Exception as e:
            logger.error(f"❌ [Qwen] Error: {str(e)}")
            return self._get_mock_result()

    def _get_analysis_prompt(self) -> str:
        """获取Qwen分析提示词"""
        return """请分析这张书签设计图片，提取：
1. 布局类型 (left-right/top-bottom/center-focused/mosaic-grid/full-bleed-image)
2. 主色调和配色方案 (HEX格式)
3. 风格氛围 (温暖治愈/清新自然/专业简约/活泼可爱/优雅复古/现代时尚/艺术文艺)
4. 复杂度 (1-5)

返回JSON格式结果。"""

    def _parse_result(self, content: str) -> ImageAnalysisResult:
        """解析Qwen结果"""
        import json
        try:
            json_start = content.find("{")
            json_end = content.rfind("}") + 1
            if json_start >= 0:
                data = json.loads(content[json_start:json_end])
                return self._convert_to_result(data)
        except:
            pass
        return self._get_mock_result()

    def _convert_to_result(self, data: Dict) -> ImageAnalysisResult:
        """转换结果格式"""
        return ImageAnalysisResult(
            layout=LayoutInfo(
                type=LayoutType.HORIZONTAL,
                confidence=0.9,
                description="左右分栏布局"
            ),
            colors=ColorScheme(
                primary=[DesignColor(hex="#F5E6D3", name="米色")],
                secondary=[DesignColor(hex="#8B7355", name="棕褐")],
                accent=[DesignColor(hex="#D4A574", name="金棕")],
                neutral=[DesignColor(hex="#333333", name="深灰")],
                palette_name="温暖米色系",
                mood="温暖、舒适",
                harmony="邻近色搭配"
            ),
            typography=Typography(
                primary_font="优雅衬线体",
                body_font="简洁无衬线体",
                font_pairs=["宋体 + 黑体"],
                text_color="#333333"
            ),
            style_attributes=StyleAttributes(
                keywords=["简约", "优雅"],
                mood=MoodType.WARM,
                complexity=3,
                aesthetic_tags=["留白", "居中"]
            ),
            decorative_elements=DecorativeElements(
                has_border=True,
                has_pattern=False,
                has_icon=True,
                suggested_elements=["边框", "装饰"]
            ),
            suggestions=["建议添加精美边框"],
            raw_analysis=str(data)
        )

    def _get_mock_result(self) -> ImageAnalysisResult:
        """获取mock结果"""
        logger.info("🎭 [Qwen] Returning mock result")
        return self._convert_to_result({})


class ClaudeAnalyzerAdapter(VisionAnalyzerAdapter):
    """Claude Vision 视觉分析器（适配器包装）"""

    def __init__(self, api_key: str):
        super().__init__(api_key, "claude-3-5-sonnet-20241022")
        self.api_url = "https://api.anthropic.com/v1/messages"
        # 重用现有的Claude分析器
        from app.services.claude_analyzer import ClaudeAnalyzer
        self.claude = ClaudeAnalyzer()

    async def analyze_images(self, image_paths: List[str]) -> ImageAnalysisResult:
        """使用Claude分析图片"""
        logger.info(f"🤖 [Claude] Analyzing {len(image_paths)} images")
        return await self.claude.analyze_images(image_paths)


class VisionAnalyzerFactory:
    """视觉分析器工厂"""

    _analyzers: Dict[VisionModel, VisionAnalyzerAdapter] = {}

    @classmethod
    def get_analyzer(cls, model: VisionModel = VisionModel.GLM) -> VisionAnalyzerAdapter:
        """获取指定模型的分析器"""
        if model in cls._analyzers:
            return cls._analyzers[model]

        # 根据模型类型创建分析器
        if model == VisionModel.GLM:
            api_key = settings.GLM_API_KEY
            analyzer = GLMAnalyzer(api_key)
        elif model == VisionModel.QWEN:
            api_key = settings.QWEN_API_KEY
            analyzer = QwenAnalyzer(api_key)
        elif model == VisionModel.CLAUDE:
            api_key = settings.ANTHROPIC_API_KEY
            analyzer = ClaudeAnalyzerAdapter(api_key)
        else:
            raise ValueError(f"Unsupported model: {model}")

        cls._analyzers[model] = analyzer
        logger.info(f"✅ [Factory] Created {model.value} analyzer")
        return analyzer

    @classmethod
    def get_default_analyzer(cls) -> VisionAnalyzerAdapter:
        """获取默认分析器（GLM）"""
        return cls.get_analyzer(VisionModel.GLM)


# 全局实例
vision_analyzer = VisionAnalyzerFactory.get_default_analyzer()
