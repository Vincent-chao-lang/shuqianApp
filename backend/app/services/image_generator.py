#
# image_generator.py
# 文生图服务（使用GLM CogView）
#

import httpx
import uuid
import jwt
import time
from pathlib import Path
from typing import Optional
from loguru import logger

from app.core.config import settings


class ImageGenerator:
    """文生图生成器（使用GLM CogView）"""

    def __init__(self):
        self.api_key = settings.GLM_API_KEY
        self.base_url = "https://open.bigmodel.cn/api/paas/v4/images/generations"
        self.model = "cogview-3-plus"  # GLM文生图模型
        self.timeout = 60.0

    def _generate_token(self) -> str:
        """
        生成GLM API所需的JWT token

        GLM API Key格式: id.secret
        需要用secret生成JWT签名
        """
        if not self.api_key:
            raise ValueError("GLM_API_KEY not configured")

        try:
            api_key_id, api_key_secret = self.api_key.split(".")
        except ValueError:
            logger.error(f"❌ [ImageGen] Invalid GLM_API_KEY format: {self.api_key[:10]}...")
            raise ValueError("GLM_API_KEY must be in format: id.secret")

        # JWT payload (GLM要求格式)
        payload = {
            "api_key": api_key_id,
            "exp": int(time.time()) * 1000 + 3600000,  # 毫秒时间戳，1小时后过期
            "timestamp": int(time.time()) * 1000  # 毫秒时间戳
        }

        # JWT header (GLM要求特定格式)
        headers = {
            "alg": "HS256",
            "sign_type": "SIGN"
        }

        # 使用HS256算法和secret生成token
        token = jwt.encode(payload, api_key_secret, algorithm="HS256", headers=headers)

        logger.debug(f"🔐 [ImageGen] Generated JWT token with API key ID: {api_key_id}")
        return token

    async def generate_image(
        self,
        prompt: str,
        size: str = "1024x1024",
        style: Optional[str] = None,
        mood: Optional[str] = None
    ) -> str:
        """
        生成图片

        Args:
            prompt: 图片描述（中文）
            size: 图片尺寸，如 "1024x1024", "768x1344" (书签竖版)
            style: 风格（可选）
            mood: 氛围（可选）

        Returns:
            str: 生成的图片URL
        """
        if not self.api_key:
            logger.warning("⚠️ [ImageGen] No GLM_API_KEY configured, returning mock")
            return self._get_mock_image_url()

        # 构建提示词
        full_prompt = self._build_prompt(prompt, style, mood)
        logger.info(f"🎨 [ImageGen] Generating image with prompt: {full_prompt[:100]}...")

        try:
            # 生成JWT token
            token = self._generate_token()

            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            }

            # GLM CogView支持的尺寸
            supported_sizes = ["1024x1024", "768x1344", "864x1152", "1344x768", "1152x864"]
            if size not in supported_sizes:
                logger.warning(f"⚠️ [ImageGen] Size {size} not supported, using 768x1344")
                size = "768x1344"  # 书签竖版

            payload = {
                "model": self.model,
                "prompt": full_prompt,
                "size": size
            }

            logger.info(f"📤 [ImageGen] Sending request to GLM API")
            logger.debug(f"   - model: {self.model}")
            logger.debug(f"   - size: {size}")
            logger.debug(f"   - prompt: {full_prompt[:50]}...")

            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(self.base_url, headers=headers, json=payload)

                # 打印详细的错误信息
                if response.status_code != 200:
                    logger.error(f"❌ [ImageGen] GLM API returned {response.status_code}")
                    logger.error(f"   Response: {response.text}")

                response.raise_for_status()
                result = response.json()

            # 提取图片URL
            if "data" in result and len(result["data"]) > 0:
                image_url = result["data"][0].get("url", "")
                logger.info(f"✅ [ImageGen] Image generated successfully")
                return image_url
            else:
                logger.warning("⚠️ [ImageGen] No image URL in response, using mock")
                return self._get_mock_image_url()

        except Exception as e:
            logger.error(f"❌ [ImageGen] Error generating image: {str(e)}")
            logger.exception("Full traceback:")
            # 失败时返回mock图片
            return self._get_mock_image_url()

    def _build_prompt(self, prompt: str, style: Optional[str], mood: Optional[str]) -> str:
        """
        构建完整的提示词

        Args:
            prompt: 用户输入的基础描述
            style: 风格
            mood: 氛围

        Returns:
            str: 完整的提示词
        """
        parts = []

        # 添加氛围（如果有）
        if mood:
            mood_map = {
                "温暖治愈": "温暖治愈风格，柔和色调",
                "清新自然": "清新自然风格，绿色植物元素",
                "专业简约": "专业简约风格，留白设计",
                "活泼可爱": "活泼可爱风格，色彩明快",
                "优雅复古": "优雅复古风格，古典元素",
                "现代时尚": "现代时尚风格，简洁设计",
                "艺术文艺": "艺术文艺风格，创意设计"
            }
            mood_desc = mood_map.get(mood, "")
            if mood_desc:
                parts.append(mood_desc)

        # 添加风格（如果有）
        if style:
            style_map = {
                "modern": "现代简约",
                "vintage": "复古风格",
                "minimal": "极简主义",
                "elegant": "优雅风格",
                "artistic": "艺术风格",
                "natural": "自然风格"
            }
            style_desc = style_map.get(style.lower(), "")
            if style_desc:
                parts.append(style_desc)

        # 添加用户描述
        parts.append(prompt)

        # 添加质量提升词
        parts.append("高质量，高清，书签背景图，竖版构图")

        return "，".join(parts)

    def _get_mock_image_url(self) -> str:
        """
        获取mock图片URL（用于测试）

        Returns:
            str: Unsplash图片URL
        """
        # 使用Unsplash的随机图片作为mock
        mock_urls = [
            "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&h=900&fit=crop",
            "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=900&fit=crop",
            "https://images.unsplash.com/photo-1497366216548-37526070297c?w=600&h=900&fit=crop",
            "https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=600&h=900&fit=crop",
            "https://images.unsplash.com/photo-1494438639946-1ebd1d20bf85?w=600&h=900&fit=crop"
        ]
        import random
        return random.choice(mock_urls)

    async def download_image(self, image_url: str) -> Path:
        """
        下载生成的图片到本地

        Args:
            image_url: 图片URL

        Returns:
            Path: 本地文件路径
        """
        logger.info(f"📥 [ImageGen] Downloading image from: {image_url}")

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(image_url)
                response.raise_for_status()
                image_data = response.content

            # 保存到临时目录
            filename = f"generated_{uuid.uuid4().hex[:8]}.jpg"
            filepath = settings.DOWNLOAD_DIR / filename

            with open(filepath, "wb") as f:
                f.write(image_data)

            logger.info(f"✅ [ImageGen] Image downloaded: {filepath}")
            return filepath

        except Exception as e:
            logger.error(f"❌ [ImageGen] Error downloading image: {str(e)}")
            raise


# 全局实例
image_generator = ImageGenerator()
