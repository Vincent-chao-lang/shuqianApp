#
# bookmark_generator.py
# 书签图像生成核心逻辑
#

import os
import uuid
import time
from pathlib import Path
from typing import Optional, List, Tuple
from datetime import datetime
from PIL import Image, ImageDraw, ImageFont, ImageColor
from PIL.Image import Resampling
from loguru import logger

from app.core.config import settings
from app.models.schemas import (
    MoodType,
    LayoutType,
    GenerateFinalRequest,
    RichTextContent,
    TextBlock,
    TextStyle,
    FontSize,
    TextDirection,
    TextAlignment,
    BackgroundSettings,
    BackgroundType,
    GradientDirection,
    TextPosition
)


class BookmarkGenerator:
    """书签图像生成器"""

    # 占位图片URL（使用Unsplash）
    PLACEHOLDER_IMAGES = {
        MoodType.WARM: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=600&fit=crop",
        MoodType.FRESH: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=600&fit=crop",
        MoodType.PROFESSIONAL: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=400&h=600&fit=crop",
        MoodType.PLAYFUL: "https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=400&h=600&fit=crop",
        MoodType.ELEGANT: "https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=400&h=600&fit=crop",
        MoodType.MODERN: "https://images.unsplash.com/photo-1494438639946-1ebd1d20bf85?w=400&h=600&fit=crop",
        MoodType.ARTISTIC: "https://images.unsplash.com/photo-1547891654-e66ed7ebb968?w=400&h=600&fit=crop",
    }

    def __init__(self):
        self.download_dir = settings.DOWNLOAD_DIR
        self.temp_dir = settings.TEMP_DIR

    def _draw_background(
        self,
        image: Image.Image,
        background: Optional[BackgroundSettings]
    ):
        """
        绘制背景（纯色/渐变/图片）

        Args:
            image: PIL图像对象
            background: 背景设置（可选）
        """
        if not background:
            return

        width, height = image.size
        draw = ImageDraw.Draw(image)

        if background.background_type == BackgroundType.SOLID:
            # 纯色背景
            if background.solid:
                color = background.solid.color
                logger.info(f"🎨 [BG] Drawing solid background: {color}")
                draw.rectangle([(0, 0), (width, height)], fill=color)

        elif background.background_type == BackgroundType.GRADIENT:
            # 渐变背景
            if background.gradient:
                self._draw_gradient(
                    image,
                    background.gradient.direction,
                    background.gradient.colors
                )

        elif background.background_type == BackgroundType.IMAGE:
            # 图片背景
            if background.image:
                self._draw_image_background(
                    image,
                    background.image.image_path,
                    background.image.opacity,
                    background.image.fit_mode
                )

    def _draw_gradient(
        self,
        image: Image.Image,
        direction: GradientDirection,
        colors: List[str]
    ):
        """
        绘制渐变背景

        Args:
            image: PIL图像对象
            direction: 渐变方向
            colors: 颜色列表（2-3个颜色）
        """
        width, height = image.size

        if direction == GradientDirection.HORIZONTAL:
            # 水平渐变（从左到右）
            for x in range(width):
                ratio = x / width
                color = self._interpolate_color(colors, ratio)
                image.paste(color, (x, 0, x + 1, height))

        elif direction == GradientDirection.VERTICAL:
            # 垂直渐变（从上到下）
            for y in range(height):
                ratio = y / height
                color = self._interpolate_color(colors, ratio)
                image.paste(color, (0, y, width, y + 1))

        elif direction == GradientDirection.DIAGONAL:
            # 对角渐变
            for y in range(height):
                for x in range(width):
                    ratio = (x + y) / (width + height)
                    color = self._interpolate_color(colors, ratio)
                    image.putpixel((x, y), color)

        elif direction == GradientDirection.RADIAL:
            # 径向渐变（从中心向外）
            import math
            center_x, center_y = width // 2, height // 2
            max_radius = math.sqrt(center_x ** 2 + center_y ** 2)

            for y in range(height):
                for x in range(width):
                    distance = math.sqrt((x - center_x) ** 2 + (y - center_y) ** 2)
                    ratio = min(distance / max_radius, 1.0)
                    color = self._interpolate_color(colors, ratio)
                    image.putpixel((x, y), color)

        logger.info(f"🎨 [BG] Drew {direction.value} gradient with {len(colors)} colors")

    def _interpolate_color(self, colors: List[str], ratio: float) -> tuple:
        """
        在多个颜色之间插值

        Args:
            colors: 颜色列表
            ratio: 插值比例（0-1）

        Returns:
            RGB元组
        """
        # 确保ratio在有效范围内
        ratio = max(0.0, min(1.0, ratio))

        if len(colors) == 1:
            return self._hex_to_rgb(colors[0])

        # 计算应该在哪两个颜色之间插值
        num_segments = len(colors) - 1
        segment = ratio * num_segments
        idx = int(segment)
        local_ratio = segment - idx

        # 获取两个颜色
        color1 = self._hex_to_rgb(colors[idx])
        color2 = self._hex_to_rgb(colors[min(idx + 1, len(colors) - 1)])

        # 线性插值
        r = int(color1[0] + (color2[0] - color1[0]) * local_ratio)
        g = int(color1[1] + (color2[1] - color1[1]) * local_ratio)
        b = int(color1[2] + (color2[2] - color1[2]) * local_ratio)

        return (r, g, b)

    def _draw_image_background(
        self,
        image: Image.Image,
        image_path: str,
        opacity: float,
        fit_mode: str
    ):
        """
        绘制图片背景

        Args:
            image: PIL图像对象
            image_path: 背景图片路径
            opacity: 不透明度（0-1）
            fit_mode: 填充模式（cover/contain/stretch）
        """
        try:
            bg_img = Image.open(image_path)

            # 转换为RGBA以支持透明度
            if bg_img.mode != "RGBA":
                bg_img = bg_img.convert("RGBA")

            # 应用不透明度
            if opacity < 1.0:
                alpha = bg_img.split()[3]
                alpha = alpha.point(lambda p: p * opacity)
                bg_img.putalpha(alpha)

            # 调整大小
            target_width, target_height = image.size

            if fit_mode == "cover":
                # 覆盖模式：保持比例，裁剪多余部分
                fitted = self._fit_image_to_zone(bg_img, target_width, target_height)
            elif fit_mode == "contain":
                # 包含模式：保持比例，可能留白
                img_ratio = bg_img.width / bg_img.height
                target_ratio = target_width / target_height

                if img_ratio > target_ratio:
                    new_width = int(target_height * img_ratio)
                    resized = bg_img.resize((new_width, target_height), Resampling.LANCZOS)
                    x = (new_width - target_width) // 2
                    fitted = resized.crop((x, 0, x + target_width, target_height))
                else:
                    new_height = int(target_width / img_ratio)
                    resized = bg_img.resize((target_width, new_height), Resampling.LANCZOS)
                    y = (new_height - target_height) // 2
                    fitted = resized.crop((0, y, target_width, y + target_height))
            else:  # stretch
                # 拉伸模式：直接拉伸
                fitted = bg_img.resize((target_width, target_height), Resampling.LANCZOS)

            # 创建合成图层
            image_rgba = image.convert("RGBA")
            image_rgba.paste(fitted, (0, 0), fitted)

            # 转换回RGB
            image.paste(image_rgba.convert("RGB"))

            logger.info(f"🎨 [BG] Drew image background (opacity={opacity}, fit={fit_mode})")

        except Exception as e:
            logger.error(f"❌ [BG] Error drawing image background: {e}")

    def generate_preview(
        self,
        mood: MoodType,
        complexity: int,
        colors: List[str],
        layout: LayoutType
    ) -> Tuple[str, int, int]:
        """
        生成低分辨率预览图（72dpi）

        Args:
            mood: 情绪类型
            complexity: 复杂度 1-5
            colors: 颜色列表
            layout: 布局类型

        Returns:
            (文件路径, 宽度, 高度)
        """
        logger.debug("🎨 [GENERATOR] generate_preview() called")
        logger.debug(f"   - Mood: {mood.value}")
        logger.debug(f"   - Complexity: {complexity}")
        logger.debug(f"   - Colors: {colors}")
        logger.debug(f"   - Layout: {layout.value}")

        gen_start = time.time()
        width, height = settings.bookmark_size_px_preview
        logger.debug(f"   - Size: {width}x{height}px @ {settings.PREVIEW_DPI}dpi")

        # 创建图片
        logger.debug("🖼️ [GENERATOR] Creating base image...")
        create_start = time.time()
        image = Image.new("RGB", (width, height), color=colors[0])
        draw = ImageDraw.Draw(image)
        logger.debug(f"   - Base image created in {time.time() - create_start:.2f}s")

        # 应用布局
        logger.debug("📐 [GENERATOR] Applying layout...")
        layout_start = time.time()
        self._apply_layout(draw, width, height, layout, colors, is_preview=True)
        logger.debug(f"   - Layout applied in {time.time() - layout_start:.2f}s")

        # 添加装饰元素（根据复杂度）
        logger.debug(f"✨ [GENERATOR] Adding decorative elements (complexity={complexity})...")
        deco_start = time.time()
        self._add_decorative_elements(draw, width, height, complexity, colors)
        logger.debug(f"   - Decorations added in {time.time() - deco_start:.2f}s")

        # 保存文件
        logger.debug("💾 [GENERATOR] Saving preview file...")
        save_start = time.time()
        filename = f"preview_{uuid.uuid4().hex[:8]}.png"
        filepath = self.download_dir / filename
        image.save(filepath, "PNG", dpi=(settings.PREVIEW_DPI, settings.PREVIEW_DPI))
        save_time = time.time() - save_start

        gen_time = time.time() - gen_start
        file_size = filepath.stat().st_size
        logger.info(f"✅ [GENERATOR] Preview generated in {gen_time:.2f}s")
        logger.info(f"   - File: {filename}")
        logger.info(f"   - Size: {file_size / 1024:.2f}KB")
        logger.info(f"   - Save time: {save_time:.2f}s")

        return (str(filepath), width, height)

    def generate_final(
        self,
        request: GenerateFinalRequest,
        user_photo_path: Optional[str] = None
    ) -> Tuple[str, str]:
        """
        生成高分辨率最终书签（300dpi）

        Args:
            request: 生成请求
            user_photo_path: 用户上传的照片路径

        Returns:
            (PNG文件路径, PDF文件路径)
        """
        logger.debug("🎯 [GENERATOR] generate_final() called")
        logger.debug(f"   - Mood: {request.mood.value}")
        logger.debug(f"   - Complexity: {request.complexity}")
        logger.debug(f"   - Layout: {request.layout.value}")
        logger.debug(f"   - Colors: {request.colors}")
        logger.debug(f"   - User text: {request.user_text[:50]}...")
        logger.debug(f"   - User photo: {user_photo_path or 'None'}")
        logger.debug(f"   - Background: {request.background.background_type.value if request.background else 'None'}")
        logger.debug(f"   - Text position: {request.text_position is not None}")
        logger.debug(f"   - Show borders: {request.show_borders}")

        gen_start = time.time()

        # 获取最终尺寸（包含出血）
        bleed_px = settings.bleed_px_final
        safe_margin = settings.safe_margin_px_final
        logger.debug(f"   - Bleed: {bleed_px}px")
        logger.debug(f"   - Safe margin: {safe_margin}px")

        content_width = settings.bookmark_size_px_final[0]
        content_height = settings.bookmark_size_px_final[1]

        total_width = content_width + 2 * bleed_px
        total_height = content_height + 2 * bleed_px
        logger.debug(f"   - Content size: {content_width}x{content_height}px")
        logger.debug(f"   - Total size (with bleed): {total_width}x{total_height}px")

        # 创建背景
        logger.debug("🖼️ [GENERATOR] Creating base image with bleed...")
        image = Image.new("RGB", (total_width, total_height), color=request.colors[0])
        draw = ImageDraw.Draw(image)

        # 定义内容区域
        content_area = (
            bleed_px,
            bleed_px,
            bleed_px + content_width,
            bleed_px + content_height
        )

        # 裁剪到内容区域
        logger.debug("✂️ [GENERATOR] Cropping to content area...")
        content_image = image.crop(content_area)
        content_draw = ImageDraw.Draw(content_image)

        # 如果有用户上传的照片，将其作为整个书签背景
        if user_photo_path and Path(user_photo_path).exists():
            logger.info("🖼️ [GENERATOR] Using user photo as full background...")
            try:
                user_photo = Image.open(user_photo_path)

                # 使用cover模式填充整个书签区域
                fitted_photo = self._fit_image_to_zone(
                    user_photo,
                    content_width,
                    content_height
                )

                # 将用户照片作为背景粘贴
                content_image.paste(fitted_photo, (0, 0))
                logger.info(f"✅ User photo applied as background: {fitted_photo.size}")

                # 重新创建draw对象，因为图片已经改变
                content_draw = ImageDraw.Draw(content_image)
            except Exception as e:
                logger.error(f"❌ [GENERATOR] Error applying user photo as background: {e}")
                logger.exception("Full traceback:")
        else:
            # 没有用户照片时，使用背景设置或默认颜色
            if request.background:
                logger.debug("🎨 [GENERATOR] Applying background settings...")
                bg_start = time.time()
                self._draw_background(content_image, request.background)
                logger.debug(f"   - Background applied in {time.time() - bg_start:.2f}s")
            else:
                # 使用第一个颜色作为默认背景
                default_color = request.colors[0] if request.colors else "#FFFFFF"
                content_draw.rectangle(
                    [(0, 0), (content_width, content_height)],
                    fill=default_color
                )
                logger.debug(f"   - Applied default background: {default_color}")

        # 添加用户文字
        logger.debug("📝 [GENERATOR] Adding user text...")
        text_start = time.time()
        self._add_user_text(
            content_draw,
            content_width,
            content_height,
            request.layout,  # 保留layout参数用于文本区域计算
            request.user_text,
            request.colors,
            request.rich_text,
            request.text_position
        )
        logger.debug(f"   - Text added in {time.time() - text_start:.2f}s")

        # 添加装饰元素（仅在show_borders为True时）
        if request.show_borders:
            logger.debug("✨ [GENERATOR] Adding decorative elements...")
            deco_start = time.time()
            self._add_decorative_elements(
                content_draw,
                content_width,
                content_height,
                request.complexity,
                request.colors
            )
            logger.debug(f"   - Decorations added in {time.time() - deco_start:.2f}s")
        else:
            logger.debug("✨ [GENERATOR] Skipping decorative elements (show_borders=False)")

        # 将内容粘贴回总画布
        logger.debug("📋 [GENERATOR] Pasting content back to canvas...")
        image.paste(content_image, (bleed_px, bleed_px))

        # 生成唯一ID
        bookmark_id = uuid.uuid4().hex[:12]
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        logger.debug(f"   - Bookmark ID: {bookmark_id}")

        # 保存PNG
        logger.info("💾 [GENERATOR] Saving PNG...")
        png_start = time.time()
        png_filename = f"bookmark_{timestamp}_{bookmark_id}.png"
        png_filepath = self.download_dir / png_filename
        image.save(png_filepath, "PNG", dpi=(settings.FINAL_DPI, settings.FINAL_DPI))
        png_save_time = time.time() - png_start
        png_size = png_filepath.stat().st_size
        logger.info(f"   - PNG saved: {png_filename} ({png_size / 1024:.2f}KB) in {png_save_time:.2f}s")

        # 保存PDF
        logger.info("💾 [GENERATOR] Saving PDF...")
        pdf_start = time.time()
        pdf_filename = f"bookmark_{timestamp}_{bookmark_id}.pdf"
        pdf_filepath = self.download_dir / pdf_filename

        # PDF需要转换为RGB颜色模式
        if image.mode != "RGB":
            logger.debug(f"   - Converting from {image.mode} to RGB")
            image = image.convert("RGB")

        # 创建PDF（包含出血信息）
        pdf_image = image.copy()
        pdf_image.save(
            pdf_filepath,
            "PDF",
            resolution=settings.FINAL_DPI,
            save_all=True
        )
        pdf_save_time = time.time() - pdf_start
        pdf_size = pdf_filepath.stat().st_size
        logger.info(f"   - PDF saved: {pdf_filename} ({pdf_size / 1024:.2f}KB) in {pdf_save_time:.2f}s")

        gen_time = time.time() - gen_start
        logger.info(f"✅ [GENERATOR] Final bookmark generated in {gen_time:.2f}s")

        return (str(png_filepath), str(pdf_filepath))

    def _apply_layout(
        self,
        draw: ImageDraw.ImageDraw,
        width: int,
        height: int,
        layout: LayoutType,
        colors: List[str],
        is_preview: bool
    ):
        """应用布局样式"""
        bg_color = colors[0] if colors else "#FFFFFF"

        if layout == LayoutType.HORIZONTAL:
            # 左图右文布局
            image_width = int(width * 0.45)
            text_width = width - image_width

            # 绘制图片占位区域
            draw.rectangle(
                [(10, 10), (image_width - 10, height - 10)],
                fill=self._lighten_color(bg_color, 20),
                outline=colors[1] if len(colors) > 1 else "#CCCCCC",
                width=2
            )

            # 绘制文字区域
            draw.rectangle(
                [(image_width, 10), (width - 10, height - 10)],
                fill=bg_color
            )

        elif layout == LayoutType.VERTICAL:
            # 上图下文布局
            image_height = int(height * 0.55)

            # 绘制图片占位区域
            draw.rectangle(
                [(10, 10), (width - 10, image_height - 10)],
                fill=self._lighten_color(bg_color, 20),
                outline=colors[1] if len(colors) > 1 else "#CCCCCC",
                width=2
            )

            # 绘制文字区域
            draw.rectangle(
                [(10, image_height), (width - 10, height - 10)],
                fill=bg_color
            )

        elif layout == LayoutType.CENTERED:
            # 居中聚焦布局
            margin = int(width * 0.15)
            draw.rectangle(
                [(margin, margin), (width - margin, height - margin)],
                fill=self._lighten_color(bg_color, 10),
                outline=colors[1] if len(colors) > 1 else "#CCCCCC",
                width=3
            )

        elif layout == LayoutType.MOSAIC:
            # 拼贴网格布局
            grid_size = 2
            cell_w = (width - 30) // grid_size
            cell_h = (height - 30) // grid_size

            for i in range(grid_size):
                for j in range(grid_size):
                    x1 = 10 + j * cell_w
                    y1 = 10 + i * cell_h
                    x2 = x1 + cell_w - 5
                    y2 = y1 + cell_h - 5

                    shade_idx = (i * grid_size + j) % len(colors)
                    draw.rectangle(
                        [(x1, y1), (x2, y2)],
                        fill=self._lighten_color(colors[shade_idx], 15),
                        outline=colors[0],
                        width=2
                    )

        elif layout == LayoutType.FULL_BLEED:
            # 全出血图片（在预览中使用渐变模拟）
            for y in range(height):
                ratio = y / height
                r = int(self._hex_to_rgb(bg_color)[0] * (1 - ratio * 0.3))
                g = int(self._hex_to_rgb(bg_color)[1] * (1 - ratio * 0.3))
                b = int(self._hex_to_rgb(bg_color)[2] * (1 - ratio * 0.3))
                draw.line([(0, y), (width, y)], fill=(r, g, b))

    def _add_user_photo(
        self,
        image: Image.Image,
        draw: ImageDraw.ImageDraw,
        width: int,
        height: int,
        layout: LayoutType,
        photo_path: str
    ):
        """添加用户照片"""
        try:
            user_photo = Image.open(photo_path)

            if layout == LayoutType.HORIZONTAL:
                # 左图区域
                target_width = int(width * 0.45)
                target_height = height - 40
                x_offset = 20
                y_offset = 20

            elif layout == LayoutType.VERTICAL:
                # 上图区域
                target_width = width - 40
                target_height = int(height * 0.55)
                x_offset = 20
                y_offset = 20

            elif layout == LayoutType.CENTERED:
                # 居中区域
                margin = int(width * 0.15)
                target_width = width - 2 * margin - 20
                target_height = int(target_width * 0.8)
                x_offset = margin + 10
                y_offset = margin + 10

            else:  # MOSAIC or FULL_BLEED
                # 使用第一个格子或全图
                target_width = width - 40
                target_height = int(height * 0.6)
                x_offset = 20
                y_offset = 20

            # 智能裁剪和缩放
            fitted_photo = self._fit_image_to_zone(
                user_photo,
                target_width,
                target_height
            )

            # 计算居中位置
            paste_x = x_offset + (target_width - fitted_photo.width) // 2
            paste_y = y_offset + (target_height - fitted_photo.height) // 2

            # 粘贴图片
            image.paste(fitted_photo, (paste_x, paste_y))

            logger.info(f"User photo added: {photo_path}")

        except Exception as e:
            logger.error(f"Error adding user photo: {e}")

    def _add_user_text(
        self,
        draw: ImageDraw.ImageDraw,
        width: int,
        height: int,
        layout: LayoutType,
        text: str,
        colors: List[str],
        rich_text: Optional[RichTextContent] = None,
        text_position: Optional[TextPosition] = None
    ):
        """添加用户文字，支持富文本"""
        try:
            # 如果提供了富文本，使用富文本渲染
            if rich_text and rich_text.blocks:
                logger.info(f"📝 [TEXT] Rendering rich text with {len(rich_text.blocks)} blocks")
                self._add_rich_text(draw, width, height, layout, rich_text, colors, text_position)
            elif text:  # 只有当有普通文本时才渲染
                # 使用普通文本渲染（保持向后兼容）
                logger.info(f"📝 [TEXT] Rendering plain text: {text[:50]}...")
                self._add_plain_text(draw, width, height, layout, text, colors, text_position)
            else:
                logger.info("📝 [TEXT] No text to render (both rich_text and user_text are empty)")

            logger.info("User text added successfully")

        except Exception as e:
            logger.error(f"Error adding user text: {e}")
            logger.exception("Full traceback:")

    def _add_rich_text(
        self,
        draw: ImageDraw.ImageDraw,
        width: int,
        height: int,
        layout: LayoutType,
        rich_text: RichTextContent,
        colors: List[str],
        text_position: Optional[TextPosition] = None
    ):
        """渲染富文本内容"""
        # 获取文本区域
        text_area = self._get_text_area(width, height, layout, text_position)

        # 渲染每个文本块
        current_y = text_area['y_start']
        line_spacing = 20  # 行间距

        for block_idx, block in enumerate(rich_text.blocks):
            logger.info(f"📝 [RICH] Rendering block {block_idx + 1}/{len(rich_text.blocks)}")
            logger.info(f"   - Text: {block.text[:30]}...")
            logger.info(f"   - Font size: {block.style.font_size.value}")
            logger.info(f"   - Direction: {block.style.direction.value}")
            logger.info(f"   - Alignment: {block.style.alignment.value}")
            logger.info(f"   - Color: {block.style.color}")

            # 计算字体大小（基于基础尺寸调整）
            base_size = max(14, width // 20)
            font_size = self._get_font_size_pixels(block.style.font_size, base_size)

            # 加载字体
            font = self._load_font(font_size)

            # 如果需要粗体
            if block.style.font_weight == "bold":
                # PIL不直接支持粗体，通过绘制多次实现
                pass

            # 获取文本颜色
            text_color = block.style.color if block.style.color else (
                colors[-1] if len(colors) > 1 else "#333333"
            )

            # 处理文字方向
            if block.style.direction == TextDirection.VERTICAL:
                current_y = self._draw_vertical_text(
                    draw, block.text, text_area, current_y, font, text_color, block.style.alignment
                )
            else:
                current_y = self._draw_horizontal_text(
                    draw, block.text, text_area, current_y, font, text_color, block.style.alignment
                )

            # 块之间的间距
            current_y += line_spacing

    def _get_font_size_pixels(self, font_size: FontSize, base_size: int) -> int:
        """将FontSize枚举转换为像素值"""
        size_map = {
            FontSize.SMALL: int(base_size * 0.7),      # 14-16px equivalent
            FontSize.MEDIUM: base_size,                 # 18-24px equivalent
            FontSize.LARGE: int(base_size * 1.4),       # 28-36px equivalent
            FontSize.EXTRA_LARGE: int(base_size * 1.8)  # 40-48px equivalent
        }
        return size_map.get(font_size, base_size)

    def _draw_horizontal_text(
        self,
        draw: ImageDraw.ImageDraw,
        text: str,
        text_area: dict,
        current_y: int,
        font: ImageFont.FreeTypeFont,
        color: str,
        alignment: TextAlignment
    ) -> int:
        """绘制水平文本"""
        text_width = text_area['width']
        x_start = text_area['x_start']

        # 自动换行
        lines = self._wrap_text_lines(draw, text, text_width - 20, font)

        for line in lines:
            # 计算x位置（基于对齐方式）
            line_bbox = draw.textbbox((0, 0), line, font=font)
            line_width = line_bbox[2] - line_bbox[0]

            if alignment == TextAlignment.CENTER:
                x = x_start + (text_width - line_width) // 2
            elif alignment == TextAlignment.RIGHT:
                x = x_start + text_width - line_width
            else:  # LEFT
                x = x_start + 10

            # 绘制文本
            draw.text((x, current_y), line, fill=color, font=font)

            # 移动到下一行
            current_y += font.size + 8

        return current_y

    def _draw_vertical_text(
        self,
        draw: ImageDraw.ImageDraw,
        text: str,
        text_area: dict,
        current_y: int,
        font: ImageFont.FreeTypeFont,
        color: str,
        alignment: TextAlignment
    ) -> int:
        """
        绘制竖排文本

        竖排规则：
        - 字符从上到下排列成一列
        - 多列从左到右排列
        - 最多10个汉字一列，最多3列
        """
        text_width = text_area['width']
        x_start = text_area['x_start']
        max_height = text_area['height'] - current_y + text_area['y_start']

        # 字符尺寸
        char_size = font.size + 8  # 字符大小 + 行间距
        # 字符宽度约等于字号（对于中文字符）
        char_width = max(font.size, 12)  # 确保最小宽度

        # 竖排限制：每列最多10个汉字，最多3列
        max_chars_per_column = 10
        max_columns_allowed = 3
        max_total_chars = max_chars_per_column * max_columns_allowed  # 最多30个字符

        # 截断过长的文本
        total_chars = len(text)
        if total_chars > max_total_chars:
            text = text[:max_total_chars]
            total_chars = max_total_chars
            logger.warning(f"⚠️ [VERTICAL] Text truncated from {len(text)} to {max_total_chars} characters")

        # 计算实际需要的列数（最多3列）
        num_columns = min(
            (total_chars + max_chars_per_column - 1) // max_chars_per_column,
            max_columns_allowed
        )

        # 确保至少有1列（如果有文字的话）
        if total_chars > 0 and num_columns == 0:
            num_columns = 1

        logger.info(f"📐 [VERTICAL] Layout: {total_chars} chars, {num_columns} columns, {max_chars_per_column} chars/column, char_width={char_width}px")

        # 计算起始x位置（基于对齐方式）
        if alignment == TextAlignment.CENTER:
            x = x_start + (text_width - num_columns * char_width) // 2
        elif alignment == TextAlignment.RIGHT:
            x = x_start + text_width - num_columns * char_width
        else:  # LEFT
            x = x_start

        # 从左到右绘制每一列
        for col in range(num_columns):
            col_x = x + col * char_width

            # 获取当前列的字符（每列最多10个字符）
            start_idx = col * max_chars_per_column
            end_idx = min(start_idx + max_chars_per_column, total_chars)
            column_chars = text[start_idx:end_idx]

            # 从上到下绘制字符
            for row, char in enumerate(column_chars):
                char_x = col_x
                char_y = current_y + row * char_size
                draw.text((char_x, char_y), char, fill=color, font=font)

        # 计算下一行的y位置（使用实际绘制的高度）
        actual_rows_used = min(total_chars, max_chars_per_column)
        return current_y + actual_rows_used * char_size + 20

    def _wrap_text_lines(
        self,
        draw: ImageDraw.ImageDraw,
        text: str,
        max_width: int,
        font: ImageFont.FreeTypeFont
    ) -> List[str]:
        """
        将文本分割为多行

        Returns:
            List[str]: 文本行列表
        """
        lines = []
        current_line = ""

        for char in text:
            test_line = current_line + char
            bbox = draw.textbbox((0, 0), test_line, font=font)
            width = bbox[2] - bbox[0]

            if width <= max_width:
                current_line = test_line
            else:
                if current_line:
                    lines.append(current_line)
                current_line = char

        if current_line:
            lines.append(current_line)

        return lines

    def _get_text_area(
        self,
        width: int,
        height: int,
        layout: LayoutType,
        text_position: Optional[TextPosition] = None
    ) -> dict:
        """
        获取文本区域的位置和尺寸

        Args:
            width: 画布宽度
            height: 画布高度
            layout: 布局类型
            text_position: 可选的自定义文本位置设置

        Returns:
            包含x_start, y_start, width, height的字典
        """
        # 如果提供了自定义文本位置，使用它
        if text_position:
            logger.info(f"📐 [TEXT] Using custom text position: "
                       f"top={text_position.top_margin}, "
                       f"bottom={text_position.bottom_margin}, "
                       f"left={text_position.left_margin}, "
                       f"right={text_position.right_margin}, "
                       f"alignment={text_position.alignment.value}, "
                       f"direction={text_position.direction.value}")

            # 根据文字方向计算文本区域宽度
            if text_position.width:
                # 用户指定了宽度，使用指定的宽度
                text_width = text_position.width
            else:
                # 根据方向自动计算宽度
                if text_position.direction == TextDirection.VERTICAL:
                    # 竖排文字：使用可用宽度（实际宽度由绘制时根据内容决定）
                    available_width = width - text_position.left_margin - text_position.right_margin
                    text_width = available_width
                else:
                    # 水平文字：书签宽度的80%
                    text_width = int(width * 0.8)

            # 计算文本区域高度
            text_height = text_position.height if text_position.height else (
                height - text_position.top_margin - text_position.bottom_margin
            )

            # 计算x_start（根据对齐方式）
            if text_position.direction == TextDirection.VERTICAL:
                # 竖排文字：x_start基于left_margin，对齐方式在绘制时处理
                x_start = text_position.left_margin
            else:
                # 水平文字：使用left_margin作为起点
                x_start = text_position.left_margin

            return {
                'x_start': x_start,
                'y_start': text_position.top_margin,
                'width': text_width,
                'height': text_height
            }

        # 否则使用布局默认的文本区域
        if layout == LayoutType.HORIZONTAL:
            # 右侧文字区域
            text_x = int(width * 0.48) + 20
            text_width = width - text_x - 20
            return {
                'x_start': text_x,
                'y_start': 40,
                'width': text_width - 20,
                'height': height - 40
            }
        elif layout == LayoutType.VERTICAL:
            # 下方文字区域
            text_y_start = int(height * 0.58)
            text_x = 20
            text_width = width - 40
            return {
                'x_start': text_x,
                'y_start': text_y_start + 40,
                'width': text_width,
                'height': height - text_y_start - 20
            }
        elif layout == LayoutType.CENTERED:
            # 居中文字
            margin = int(width * 0.15)
            text_y_start = margin + int((height - 2 * margin) * 0.65)
            text_width = width - 2 * margin - 40
            return {
                'x_start': margin + 20,
                'y_start': text_y_start,
                'width': text_width,
                'height': height - text_y_start - 20
            }
        else:  # MOSAIC or FULL_BLEED
            # 底部文字区域
            text_height = int(height * 0.25)
            text_y = height - text_height - 20
            text_width = width - 40
            return {
                'x_start': 20,
                'y_start': text_y + 20,
                'width': text_width,
                'height': text_height - 20
            }

    def _add_plain_text(
        self,
        draw: ImageDraw.ImageDraw,
        width: int,
        height: int,
        layout: LayoutType,
        text: str,
        colors: List[str],
        text_position: Optional[TextPosition] = None
    ):
        """添加普通文本（向后兼容）"""
        try:
            # 获取文本区域
            text_area = self._get_text_area(width, height, layout, text_position)

            # 尝试加载字体
            font_size = max(16, width // 15)
            font = self._load_font(font_size)
            title_font = self._load_font(int(font_size * 1.5))

            text_color = colors[-1] if len(colors) > 1 else "#333333"

            # 获取文字方向和对齐方式
            text_direction = text_position.direction if text_position else TextDirection.HORIZONTAL
            text_alignment = text_position.alignment if text_position else TextAlignment.CENTER

            logger.info(f"📝 [PLAIN] Text direction: {text_direction.value}, alignment: {text_alignment.value}")

            # 根据方向选择绘制方法
            if text_direction == TextDirection.VERTICAL:
                # 竖排文字：使用竖排绘制方法
                y_start = text_area['y_start']
                self._draw_vertical_text(
                    draw, text, text_area, y_start, font, text_color, text_alignment
                )
            else:
                # 水平文字：使用原有的换行方法
                text_x = text_area['x_start']
                text_y_start = text_area['y_start']
                text_width = text_area['width']

                # 直接绘制用户文本（自动换行）
                y_offset = text_y_start
                self._wrap_text(
                    draw,
                    text,
                    (text_x, y_offset),
                    text_width,
                    font,
                    text_color
                )

        except Exception as e:
            logger.error(f"Error adding plain text: {e}")
            logger.exception("Full traceback:")

    def _add_decorative_elements(
        self,
        draw: ImageDraw.ImageDraw,
        width: int,
        height: int,
        complexity: int,
        colors: List[str]
    ):
        """根据复杂度添加装饰元素"""
        accent_color = colors[1] if len(colors) > 1 else colors[0]

        if complexity >= 2:
            # 添加边框
            border_width = 3 if complexity >= 4 else 2
            margin = 10
            draw.rectangle(
                [(margin, margin), (width - margin - 1, height - margin - 1)],
                outline=accent_color,
                width=border_width
            )

        if complexity >= 3:
            # 添加角落装饰
            corner_size = 15
            line_width = 2

            # 左上角
            draw.line([(0, corner_size), (0, 0), (corner_size, 0)], fill=accent_color, width=line_width)
            # 右上角
            draw.line([(width - corner_size, 0), (width - 1, 0), (width - 1, corner_size)], fill=accent_color, width=line_width)
            # 左下角
            draw.line([(0, height - corner_size - 1), (0, height - 1), (corner_size, height - 1)], fill=accent_color, width=line_width)
            # 右下角
            draw.line([(width - corner_size - 1, height - 1), (width - 1, height - 1), (width - 1, height - corner_size - 1)], fill=accent_color, width=line_width)

        if complexity >= 4:
            # 添加小圆点装饰
            dot_size = 4
            dot_margin = 20
            positions = [
                (dot_margin, dot_margin),
                (width - dot_margin, dot_margin),
                (dot_margin, height - dot_margin),
                (width - dot_margin, height - dot_margin),
            ]

            for x, y in positions:
                draw.ellipse(
                    [(x - dot_size, y - dot_size), (x + dot_size, y + dot_size)],
                    fill=colors[-1] if len(colors) > 2 else accent_color
                )

        if complexity >= 5:
            # 添加分割线
            line_y = height - 50
            draw.line(
                [(40, line_y), (width - 40, line_y)],
                fill=accent_color,
                width=1
            )

    def _fit_image_to_zone(
        self,
        image: Image.Image,
        target_width: int,
        target_height: int
    ) -> Image.Image:
        """
        智能裁剪图片以适应目标区域

        使用"smart crop"策略：
        1. 计算目标区域和原图的宽高比
        2. 选择适当的裁剪方式（中心、边缘等）
        3. 缩放到目标尺寸
        """
        # 计算宽高比
        target_ratio = target_width / target_height
        img_ratio = image.width / image.height

        if abs(target_ratio - img_ratio) < 0.1:
            # 比例相近，直接缩放
            return image.resize((target_width, target_height), Resampling.LANCZOS)

        # 需要裁剪
        if img_ratio > target_ratio:
            # 原图更宽，裁剪两侧
            new_width = int(image.height * target_ratio)
            left = (image.width - new_width) // 2
            cropped = image.crop((left, 0, left + new_width, image.height))
        else:
            # 原图更高，裁剪上下
            new_height = int(image.width / target_ratio)
            top = (image.height - new_height) // 2
            cropped = image.crop((0, top, image.width, top + new_height))

        return cropped.resize((target_width, target_height), Resampling.LANCZOS)

    def _wrap_text(
        self,
        draw: ImageDraw.ImageDraw,
        text: str,
        position: Tuple[int, int],
        max_width: int,
        font: ImageFont.FreeTypeFont,
        color: str
    ):
        """
        文字自动换行

        Args:
            draw: ImageDraw对象
            text: 要绘制的文字
            position: 起始位置 (x, y)
            max_width: 最大宽度
            font: 字体
            color: 颜色
        """
        x, y = position
        lines = []
        current_line = ""

        for char in text:
            test_line = current_line + char
            bbox = draw.textbbox((0, 0), test_line, font=font)
            width = bbox[2] - bbox[0]

            if width <= max_width:
                current_line = test_line
            else:
                if current_line:
                    lines.append(current_line)
                current_line = char

        if current_line:
            lines.append(current_line)

        # 绘制每一行
        line_height = font.size + 8
        for i, line in enumerate(lines):
            draw.text((x, y + i * line_height), line, fill=color, font=font)

    def _load_font(self, size: int) -> ImageFont.FreeTypeFont:
        """加载字体，支持中英文"""
        # 按优先级尝试加载系统字体
        font_paths = [
            # macOS 中文字体
            "/System/Library/Fonts/STHeiti Medium.ttc",
            "/System/Library/Fonts/STHeiti Light.ttc",
            "/System/Library/Fonts/Hiragino Sans GB.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/Supplemental/Songti.ttc",
            # Linux 中文字体
            "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
            "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
            "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
            # Windows 中文字体
            "C:/Windows/Fonts/msyh.ttc",
            "C:/Windows/Fonts/simhei.ttf",
            # 回退字体
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ]

        for font_path in font_paths:
            path_obj = Path(font_path)
            if path_obj.exists():
                try:
                    logger.info(f"✅ [FONT] Successfully loaded: {font_path}")
                    return ImageFont.truetype(str(path_obj), size)
                except Exception as e:
                    logger.warning(f"⚠️  [FONT] Failed to load {font_path}: {e}")
                    continue

        # 如果所有字体都失败，使用默认字体（不支持中文）
        logger.warning("⚠️  [FONT] No Chinese font found, using default font (Chinese characters will show as squares)")
        logger.warning("⚠️  [FONT] Please install Chinese fonts (STHeiti, Hiragino, PingFang, etc.)")
        return ImageFont.load_default()

    def _hex_to_rgb(self, hex_color: str) -> Tuple[int, int, int]:
        """十六进制颜色转RGB"""
        hex_color = hex_color.lstrip("#")
        return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

    def _lighten_color(self, hex_color: str, percent: int) -> str:
        """使颜色变亮"""
        r, g, b = self._hex_to_rgb(hex_color)
        r = min(255, int(r * (1 + percent / 100)))
        g = min(255, int(g * (1 + percent / 100)))
        b = min(255, int(b * (1 + percent / 100)))
        return f"#{r:02X}{g:02X}{b:02X}"

    def _draw_safe_zone_guide(
        self,
        draw: ImageDraw.ImageDraw,
        width: int,
        height: int,
        bleed: int,
        safe_margin: int
    ):
        """绘制安全区参考线（用于调试）"""
        # 出血线（红色虚线）
        draw.rectangle(
            [(bleed, bleed), (width - bleed, height - bleed)],
            outline="#FF0000",
            width=1
        )

        # 安全线（绿色虚线）
        draw.rectangle(
            [(bleed + safe_margin, bleed + safe_margin),
             (width - bleed - safe_margin, height - bleed - safe_margin)],
            outline="#00FF00",
            width=1
        )


# 全局实例
bookmark_generator = BookmarkGenerator()
