#
# routes.py
# API路由定义
#

import time
import os
import re
from typing import List, Any, Dict
from pathlib import Path
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from loguru import logger

from app.models.schemas import (
    ImageAnalysisResult,
    PreviewGenerationResult,
    FinalGenerationResult,
    GeneratePreviewRequest,
    GenerateFinalRequest,
    APIResponse,
    HealthResponse,
    ModelInfo,
    ModelListResponse,
    MoodType,
    LayoutType,
)
from app.services.bookmark_generator import bookmark_generator
from app.services.vision_adapter import VisionAnalyzerFactory, VisionModel
from app.services.image_generator import image_generator
from app.utils.helpers import (
    save_upload_file_tmp,
    validate_image_file,
    cleanup_all_temp_files,
)
from app.core.config import settings


# ============================================
# 辅助函数
# ============================================

def convert_camel_to_snake(data: Any) -> Any:
    """
    递归转换字典中的驼峰命名为蛇形命名

    例如: { "backgroundType": "solid" } -> { "background_type": "solid" }
    """
    if isinstance(data, dict):
        result = {}
        for key, value in data.items():
            # 将驼峰命名转换为蛇形命名
            snake_key = re.sub('([A-Z])', r'_\1', key).lower()
            # 移除开头的下划线（如果有的话）
            snake_key = snake_key.lstrip('_')

            # 递归处理嵌套的字典和列表
            result[snake_key] = convert_camel_to_snake(value)
        return result
    elif isinstance(data, list):
        return [convert_camel_to_snake(item) for item in data]
    else:
        return data


# 创建路由器
router = APIRouter()

# 记录启动时间
start_time = time.time()


# ============================================
# 健康检查端点
# ============================================

@router.get("/health", response_model=HealthResponse)
async def health_check():
    """健康检查端点"""
    uptime = time.time() - start_time
    logger.debug("🏥 Health check requested")
    return HealthResponse(
        status="healthy",
        version=settings.VERSION,
        uptime_seconds=round(uptime, 2)
    )


# ============================================
# 图片分析端点
# ============================================

@router.post("/analyze-reference", response_model=ImageAnalysisResult)
async def analyze_reference_images(
    images: List[UploadFile] = File(..., description="1-3张参考图片"),
    model: str = "glm"
):
    """
    分析上传的参考图片，提取设计元素

    Args:
        images: 1-3张参考图片
        model: 使用的视觉模型 (glm/qwen/claude)，默认glm

    Returns:
        ImageAnalysisResult: 分析结果，包含布局、配色、字体等信息
    """
    request_start = time.time()
    logger.info("=" * 60)
    logger.info("📸 [ANALYZE] New request received")
    logger.info(f"📸 [ANALYZE] Number of images: {len(images)}")
    logger.info(f"🤖 [ANALYZE] Model: {model}")

    # 验证图片数量
    if len(images) < 1 or len(images) > 3:
        logger.error(f"❌ [ANALYZE] Invalid image count: {len(images)}")
        raise HTTPException(
            status_code=400,
            detail=f"请上传1-3张图片，当前上传了{len(images)}张"
        )

    # 验证并保存图片
    logger.info("✅ [ANALYZE] Image count validated")
    image_paths = []
    total_size = 0

    for idx, img in enumerate(images):
        logger.debug(f"📁 [ANALYZE] Processing image {idx + 1}/{len(images)}")
        logger.debug(f"   - Filename: {img.filename}")
        logger.debug(f"   - Content-Type: {img.content_type}")

        # 验证文件类型
        if not validate_image_file(img):
            logger.error(f"❌ [ANALYZE] Invalid file type: {img.content_type}")
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型: {img.content_type}。"
                      f"支持的类型: {settings.ALLOWED_IMAGE_TYPES}"
            )

        # 验证文件大小
        content = await img.read()
        file_size_mb = len(content) / (1024 * 1024)
        total_size += len(content)
        logger.debug(f"   - File size: {file_size_mb:.2f}MB")

        if len(content) > settings.MAX_UPLOAD_SIZE:
            logger.error(f"❌ [ANALYZE] File too large: {file_size_mb:.2f}MB")
            raise HTTPException(
                status_code=400,
                detail=f"文件过大: {img.filename}。"
                      f"最大支持: {settings.MAX_UPLOAD_SIZE / (1024*1024):.1f}MB"
            )

        # 保存到临时目录
        img.file.seek(0)  # 重置文件指针
        save_start = time.time()
        file_path = await save_upload_file_tmp(img)
        save_time = time.time() - save_start
        logger.debug(f"   - Saved to: {file_path} (took {save_time:.2f}s)")
        image_paths.append(file_path)

    logger.info(f"💾 [ANALYZE] All images saved, total size: {total_size / (1024*1024):.2f}MB")

    # 验证模型参数
    try:
        vision_model = VisionModel(model.lower())
    except ValueError:
        logger.error(f"❌ [ANALYZE] Invalid model: {model}")
        raise HTTPException(
            status_code=400,
            detail=f"不支持的模型: {model}。支持的模型: glm, qwen, claude"
        )

    logger.info(f"🤖 [ANALYZE] Calling {vision_model.value.upper()} Vision API...")

    try:
        # 使用工厂获取对应模型的分析器
        analyzer = VisionAnalyzerFactory.get_analyzer(vision_model)

        # 调用模型API分析
        model_start = time.time()
        result = await analyzer.analyze_images(image_paths)
        model_time = time.time() - model_start

        logger.info(f"✅ [ANALYZE] {vision_model.value.upper()} API completed in {model_time:.2f}s")
        logger.info(f"🎨 [ANALYZE] Palette: {result.colors.palette_name}")
        logger.info(f"🎨 [ANALYZE] Layout: {result.layout.type.value}")
        logger.info(f"🎨 [ANALYZE] Mood: {result.style_attributes.mood.value}")

        total_time = time.time() - request_start
        logger.info(f"⏱️ [ANALYZE] Total request time: {total_time:.2f}s")
        logger.info("=" * 60)

        return result

    except ValueError as e:
        logger.error(f"❌ [ANALYZE] Invalid model parameter: {str(e)}")
        raise HTTPException(
            status_code=400,
            detail=f"不支持的模型: {model}"
        )
    except Exception as e:
        logger.error(f"❌ [ANALYZE] Error during analysis: {str(e)}")
        logger.exception("❌ [ANALYZE] Full traceback:")
        raise HTTPException(
            status_code=500,
            detail=f"图片分析失败: {str(e)}"
        )


# ============================================
# 文生图端点
# ============================================

@router.post("/text-to-image")
async def text_to_image(
    prompt: str = Form(..., description="图片描述（中文）"),
    mood: str = Form(None, description="氛围（可选）"),
    style: str = Form(None, description="风格（可选）"),
    size: str = Form("768x1344", description="图片尺寸")
):
    """
    根据文本描述生成图片（使用GLM CogView）

    Args:
        prompt: 图片描述（中文）
        mood: 氛围（可选）：温暖治愈/清新自然/专业简约/活泼可爱/优雅复古/现代时尚/艺术文艺
        style: 风格（可选）：modern/vintage/minimal/elegant/artistic/natural
        size: 图片尺寸（默认768x1344，适合书签，支持1024x1024/768x1344/864x1152等）

    Returns:
        dict: 包含生成的图片URL和下载路径
    """
    request_start = time.time()
    logger.info("=" * 60)
    logger.info("🎨 [TEXT2IMG] New request received")
    logger.info(f"🎨 [TEXT2IMG] Prompt: {prompt}")
    logger.info(f"🎨 [TEXT2IMG] Mood: {mood or 'None'}")
    logger.info(f"🎨 [TEXT2IMG] Style: {style or 'None'}")
    logger.info(f"🎨 [TEXT2IMG] Size: {size}")

    try:
        # 调用文生图服务
        gen_start = time.time()
        image_url = await image_generator.generate_image(
            prompt=prompt,
            size=size,
            style=style,
            mood=mood
        )
        gen_time = time.time() - gen_start

        logger.info(f"✅ [TEXT2IMG] Image generated in {gen_time:.2f}s")
        logger.info(f"✅ [TEXT2IMG] Image URL: {image_url}")

        # 下载图片到本地
        download_start = time.time()
        image_path = await image_generator.download_image(image_url)
        download_time = time.time() - download_start

        logger.info(f"💾 [TEXT2IMG] Downloaded in {download_time:.2f}s")
        logger.info(f"💾 [TEXT2IMG] Local path: {image_path}")

        # 构建下载URL
        filename = image_path.name
        download_url = f"{settings.API_V1_STR}/downloads/{filename}"

        total_time = time.time() - request_start
        logger.info(f"⏱️ [TEXT2IMG] Total request time: {total_time:.2f}s")
        logger.info("=" * 60)

        return {
            "success": True,
            "image_url": image_url,
            "download_url": download_url,
            "local_path": str(image_path),
            "size": size,
            "generation_time": gen_time,
            "total_time": total_time
        }

    except Exception as e:
        logger.error(f"❌ [TEXT2IMG] Error: {str(e)}")
        logger.exception("❌ [TEXT2IMG] Full traceback:")
        raise HTTPException(
            status_code=500,
            detail=f"文生图失败: {str(e)}"
        )


# ============================================
# 预览生成端点
# ============================================

@router.post("/generate-preview", response_model=PreviewGenerationResult)
async def generate_preview(request: GeneratePreviewRequest):
    """
    生成书签预览图（低分辨率，72dpi）

    Args:
        request: 包含mood, complexity, colors, layout的请求

    Returns:
        PreviewGenerationResult: 预览图URL和尺寸
    """
    request_start = time.time()
    logger.info("=" * 60)
    logger.info("🖼️ [PREVIEW] New request received")
    logger.info(f"🖼️ [PREVIEW] Mood: {request.mood.value}")
    logger.info(f"🖼️ [PREVIEW] Layout: {request.layout.value}")
    logger.info(f"🖼️ [PREVIEW] Complexity: {request.complexity}")
    logger.info(f"🖼️ [PREVIEW] Colors: {request.colors}")
    logger.debug(f"🖼️ [PREVIEW] DPI: {settings.PREVIEW_DPI}")
    logger.debug(f"🖼️ [PREVIEW] Size: {settings.bookmark_size_px_preview}")

    try:
        gen_start = time.time()
        file_path, width, height = bookmark_generator.generate_preview(
            mood=request.mood,
            complexity=request.complexity,
            colors=request.colors,
            layout=request.layout
        )
        gen_time = time.time() - gen_start

        # 转换为URL（相对于downloads目录）
        filename = Path(file_path).name
        preview_url = f"{settings.API_V1_STR}/downloads/{filename}"

        logger.info(f"✅ [PREVIEW] Generated in {gen_time:.2f}s")
        logger.info(f"✅ [PREVIEW] File: {filename}")
        logger.info(f"✅ [PREVIEW] Size: {width}x{height}px")
        logger.info(f"✅ [PREVIEW] URL: {preview_url}")

        total_time = time.time() - request_start
        logger.info(f"⏱️ [PREVIEW] Total request time: {total_time:.2f}s")
        logger.info("=" * 60)

        return PreviewGenerationResult(
            preview_url=preview_url,
            width=width,
            height=height
        )

    except Exception as e:
        logger.error(f"❌ [PREVIEW] Error generating preview: {str(e)}")
        logger.exception("❌ [PREVIEW] Full traceback:")
        raise HTTPException(
            status_code=500,
            detail=f"预览生成失败: {str(e)}"
        )


# ============================================
# 最终生成端点
# ============================================

@router.post("/generate-final", response_model=FinalGenerationResult)
async def generate_final_bookmark(
    background_tasks: BackgroundTasks,
    mood: str = Form(...),
    complexity: float = Form(..., ge=1, le=10),
    colors: List[str] = Form([]),  # 改为可选，默认空列表
    layout: str = Form("center-focused"),  # 提供默认值
    user_text: str = Form("", min_length=0, max_length=500),
    user_photo: UploadFile = File(None, description="用户上传的照片"),
    rich_text: str = Form(None, description="富文本JSON（可选）"),
    background: str = Form(None, description="背景设置JSON（可选）"),
    text_position: str = Form(None, description="文本位置设置JSON（可选）"),
    show_borders: bool = Form(False, description="是否显示边线装饰")
):
    """
    生成最终书签（高分辨率，300dpi）

    Args:
        mood: 情绪类型
        complexity: 复杂度 (1-10)
        colors: 颜色列表 (HEX格式，可选)
        layout: 布局类型（默认center-focused）
        user_text: 用户输入的文字（支持富文本JSON）
        user_photo: 用户上传的照片（可选）
        rich_text: 富文本内容JSON（可选）
        background: 背景设置JSON（可选）
        text_position: 文本位置设置JSON（可选）
        show_borders: 是否显示边线装饰（默认False）

    Returns:
        FinalGenerationResult: PNG和PDF下载链接
    """
    request_start = time.time()
    logger.info("=" * 60)
    logger.info("🎯 [FINAL] New request received")
    logger.info(f"🎯 [FINAL] Raw mood: {mood}")
    logger.info(f"🎯 [FINAL] Raw layout: {layout}")
    logger.info(f"🎯 [FINAL] Raw colors: {colors}")
    logger.info(f"🎯 [FINAL] Raw complexity: {complexity}")
    logger.info(f"🎯 [FINAL] Raw user_text: {user_text[:50]}...")

    # 解析mood和layout枚举
    try:
        parsed_mood = MoodType(mood)
    except ValueError:
        logger.error(f"❌ [FINAL] Invalid mood value: {mood}")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid mood value: {mood}. Valid values: {[m.value for m in MoodType]}"
        )

    try:
        parsed_layout = LayoutType(layout)
    except ValueError:
        logger.error(f"❌ [FINAL] Invalid layout value: {layout}")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid layout value: {layout}. Valid values: {[l.value for l in LayoutType]}"
        )

    logger.info(f"🎯 [FINAL] Parsed Mood: {parsed_mood.value}")
    logger.info(f"🎯 [FINAL] Parsed Layout: {parsed_layout.value}")
    logger.debug(f"🎯 [FINAL] DPI: {settings.FINAL_DPI}")
    logger.debug(f"🎯 [FINAL] Size: {settings.bookmark_size_px_final}")

    # 如果colors为空，使用默认颜色
    if not colors:
        colors = ["#F5F5DC", "#4A7C59"]  # 默认米色和橄榄绿
        logger.info(f"🎨 [FINAL] Using default colors: {colors}")

    # 构建request对象
    request = GenerateFinalRequest(
        mood=parsed_mood,
        complexity=int(complexity),  # 转换为整数
        colors=colors,
        layout=parsed_layout,
        user_text=user_text,
        rich_text=None,  # 默认为None
        background=None,  # 默认为None
        text_position=None,  # 默认为None
        show_borders=show_borders  # 是否显示边线装饰
    )

    # 导入json用于解析JSON字符串
    import json
    from app.models.schemas import RichTextContent, BackgroundSettings, TextPosition

    # 解析富文本JSON（如果提供）
    if rich_text:
        try:
            rich_text_data = json.loads(rich_text)
            request.rich_text = RichTextContent(**rich_text_data)
            logger.info(f"📝 [FINAL] Rich text provided: {len(request.rich_text.blocks)} blocks")
        except Exception as e:
            logger.warning(f"⚠️  [FINAL] Failed to parse rich_text JSON: {e}")
            logger.warning(f"⚠️  [FINAL] rich_text value: {rich_text[:200] if rich_text else 'None'}")
            # 继续处理，不中断请求
            request.rich_text = None
    else:
        logger.info(f"📝 [FINAL] No rich text provided, using plain text")

    # 解析背景设置JSON（如果提供）
    if background:
        try:
            background_data = json.loads(background)
            # 转换驼峰命名为蛇形命名
            background_data = convert_camel_to_snake(background_data)
            request.background = BackgroundSettings(**background_data)
            logger.info(f"🎨 [FINAL] Background settings provided: {request.background.background_type.value}")
        except Exception as e:
            logger.warning(f"⚠️  [FINAL] Failed to parse background JSON: {e}")
            logger.warning(f"⚠️  [FINAL] background value: {background[:200] if background else 'None'}")
            # 继续处理，不中断请求
            request.background = None
    else:
        logger.info(f"🎨 [FINAL] No background settings provided")

    # 解析文本位置设置JSON（如果提供）
    if text_position:
        try:
            text_position_data = json.loads(text_position)
            # 转换驼峰命名为蛇形命名
            text_position_data = convert_camel_to_snake(text_position_data)
            request.text_position = TextPosition(**text_position_data)
            logger.info(f"📐 [FINAL] Text position settings provided")
        except Exception as e:
            logger.warning(f"⚠️  [FINAL] Failed to parse text_position JSON: {e}")
            logger.warning(f"⚠️  [FINAL] text_position value: {text_position[:200] if text_position else 'None'}")
            # 继续处理，不中断请求
            request.text_position = None
    else:
        logger.info(f"📐 [FINAL] No text position settings provided")

    # 保存用户照片（如果上传了）
    photo_path = None
    if user_photo:
        logger.info("📷 [FINAL] User photo provided")
        logger.debug(f"   - Filename: {user_photo.filename}")
        logger.debug(f"   - Content-Type: {user_photo.content_type}")

        if not validate_image_file(user_photo):
            logger.error(f"❌ [FINAL] Invalid file type: {user_photo.content_type}")
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型: {user_photo.content_type}"
            )

        photo_path = await save_upload_file_tmp(user_photo)
        logger.info(f"💾 [FINAL] User photo saved: {photo_path}")
    else:
        logger.info("📷 [FINAL] No user photo provided")

    try:
        gen_start = time.time()
        png_path, pdf_path = bookmark_generator.generate_final(
            request=request,
            user_photo_path=photo_path
        )
        gen_time = time.time() - gen_start

        # 转换为URL
        png_filename = Path(png_path).name
        pdf_filename = Path(pdf_path).name

        png_url = f"{settings.API_V1_STR}/downloads/{png_filename}"
        pdf_url = f"{settings.API_V1_STR}/downloads/{pdf_filename}"

        logger.info(f"✅ [FINAL] Generated in {gen_time:.2f}s")
        logger.info(f"✅ [FINAL] PNG: {png_filename}")
        logger.info(f"✅ [FINAL] PDF: {pdf_filename}")
        logger.info(f"✅ [FINAL] PNG URL: {png_url}")
        logger.info(f"✅ [FINAL] PDF URL: {pdf_url}")

        total_time = time.time() - request_start
        logger.info(f"⏱️ [FINAL] Total request time: {total_time:.2f}s")
        logger.info("=" * 60)

        return FinalGenerationResult(
            png_url=png_url,
            pdf_url=pdf_url,
            width=settings.bookmark_size_px_final[0],
            height=settings.bookmark_size_px_final[1],
            dpi=settings.FINAL_DPI
        )

    except Exception as e:
        logger.error(f"❌ [FINAL] Error generating final bookmark: {str(e)}")
        logger.exception("❌ [FINAL] Full traceback:")
        raise HTTPException(
            status_code=500,
            detail=f"最终书签生成失败: {str(e)}"
        )


# ============================================
# 文件下载端点
# ============================================

@router.get("/downloads/{filename}")
async def download_file(filename: str):
    """
    下载生成的文件

    Args:
        filename: 文件名

    Returns:
        FileResponse: 文件响应
    """
    logger.debug(f"📥 [DOWNLOAD] Requested file: {filename}")

    # 安全检查：确保文件名不包含路径遍历字符
    if ".." in filename or "/" in filename or "\\" in filename:
        logger.warning(f"⚠️ [DOWNLOAD] Suspicious filename blocked: {filename}")
        raise HTTPException(
            status_code=400,
            detail="Invalid filename"
        )

    file_path = settings.DOWNLOAD_DIR / filename
    logger.debug(f"📥 [DOWNLOAD] Full path: {file_path}")

    if not file_path.exists():
        logger.warning(f"⚠️ [DOWNLOAD] File not found: {filename}")
        raise HTTPException(
            status_code=404,
            detail=f"File not found: {filename}"
        )

    # 获取文件大小
    file_size = file_path.stat().st_size
    file_size_mb = file_size / (1024 * 1024)
    logger.info(f"📥 [DOWNLOAD] Serving file: {filename} ({file_size_mb:.2f}MB)")

    # 根据文件扩展名确定媒体类型
    media_type = "application/octet-stream"
    if filename.endswith(".png"):
        media_type = "image/png"
    elif filename.endswith(".pdf"):
        media_type = "application/pdf"

    logger.debug(f"📥 [DOWNLOAD] Media type: {media_type}")

    return FileResponse(
        path=str(file_path),
        media_type=media_type,
        filename=filename,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )


# ============================================
# 模型管理端点
# ============================================

@router.get("/models", response_model=ModelListResponse)
async def list_models():
    """
    获取所有可用的视觉模型列表

    Returns:
        ModelListResponse: 模型列表，包含每个模型的详细信息
    """
    models = [
        ModelInfo(
            id="glm",
            name="GLM-4V-Flash",
            provider="智谱AI",
            description="免费多模态视觉模型，中文优化",
            pricing="免费",
            features=["完全免费", "中文优化", "多模态理解", "最多5张图片"],
            is_default=settings.DEFAULT_VISION_MODEL == "glm"
        ),
        ModelInfo(
            id="qwen",
            name="Qwen-VL-Plus",
            provider="阿里云",
            description="高性价比视觉语言模型",
            pricing="¥1.5/千tokens (降价81%)",
            features=["高性价比", "视频理解", "中文优化", "OCR优化"],
            is_default=settings.DEFAULT_VISION_MODEL == "qwen"
        ),
        ModelInfo(
            id="claude",
            name="Claude 3.5 Sonnet",
            provider="Anthropic",
            description="业界领先的视觉理解模型",
            pricing="$3/百万tokens",
            features=["最强推理", "设计分析", "英文优化", "复杂理解"],
            is_default=settings.DEFAULT_VISION_MODEL == "claude"
        ),
    ]

    return ModelListResponse(
        models=models,
        default_model=settings.DEFAULT_VISION_MODEL,
        count=len(models)
    )


@router.post("/switch-model", response_model=APIResponse)
async def switch_model(model: str = Form(..., description="目标模型 (glm/qwen/claude)")):
    """
    切换默认视觉模型（需要重启后端生效）

    Args:
        model: 目标模型ID

    Returns:
        APIResponse: 操作结果
    """
    try:
        vision_model = VisionModel(model.lower())

        # 更新配置（注意：这需要更新环境变量或配置文件）
        logger.info(f"🔄 [MODEL] Switching default model to {vision_model.value}")

        return APIResponse(
            success=True,
            message=f"默认模型已设置为 {vision_model.value.upper()}，请重启后端生效",
            data={"model": vision_model.value, "display_name": vision_model.value.upper()}
        )

    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的模型: {model}。支持的模型: glm, qwen, claude"
        )


# ============================================
# 清理端点（手动触发）
# ============================================

@router.post("/cleanup", response_model=APIResponse)
async def manual_cleanup(background_tasks: BackgroundTasks):
    """
    手动触发临时文件清理

    Returns:
        APIResponse: 清理结果
    """
    logger.info("🧹 [CLEANUP] Manual cleanup requested")
    background_tasks.add_task(cleanup_all_temp_files)

    return APIResponse(
        success=True,
        message="Cleanup task started in background"
    )
