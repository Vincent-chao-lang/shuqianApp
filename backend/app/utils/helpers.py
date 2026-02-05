#
# helpers.py
# 辅助工具函数
#

import os
import time
import aiofiles
from pathlib import Path
from typing import Optional
from datetime import datetime, timedelta
from fastapi import UploadFile
from loguru import logger

from app.core.config import settings


async def save_upload_file(
    upload_file: UploadFile,
    destination: Path = None
) -> str:
    """
    保存上传的文件

    Args:
        upload_file: FastAPI UploadFile对象
        destination: 目标目录，默认为UPLOAD_DIR

    Returns:
        保存的文件路径
    """
    logger.debug("📁 [HELPER] save_upload_file() called")
    logger.debug(f"   - Original filename: {upload_file.filename}")
    logger.debug(f"   - Content-Type: {upload_file.content_type}")

    if destination is None:
        destination = settings.UPLOAD_DIR

    logger.debug(f"   - Destination: {destination}")

    # 确保目标目录存在
    destination.mkdir(parents=True, exist_ok=True)

    # 生成文件名
    file_extension = Path(upload_file.filename).suffix
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"upload_{timestamp}_{upload_file.filename[:50]}{file_extension}"
    file_path = destination / filename

    # 保存文件
    logger.debug("💾 [HELPER] Writing file to disk...")
    write_start = time.time()
    async with aiofiles.open(file_path, "wb") as f:
        content = await upload_file.read()
        write_time = time.time() - write_start
        await f.write(content)

    file_size = len(content)
    logger.info(f"✅ [HELPER] File saved: {filename}")
    logger.info(f"   - Size: {file_size / 1024:.2f}KB")
    logger.info(f"   - Write time: {write_time:.2f}s")
    logger.debug(f"   - Path: {file_path}")

    return str(file_path)


async def save_upload_file_tmp(
    upload_file: UploadFile
) -> str:
    """
    保存上传的文件到临时目录

    Args:
        upload_file: FastAPI UploadFile对象

    Returns:
        保存的文件路径
    """
    logger.debug("📁 [HELPER] save_upload_file_tmp() called")
    return await save_upload_file(upload_file, settings.TEMP_DIR)


def validate_image_file(file: UploadFile) -> bool:
    """
    验证上传的文件是否为允许的图片类型

    Args:
        file: FastAPI UploadFile对象

    Returns:
        是否为有效的图片文件
    """
    logger.debug(f"🔍 [HELPER] Validating file type: {file.content_type}")

    if not file.content_type:
        logger.debug("   - No content-type, rejecting")
        return False

    is_valid = file.content_type in settings.ALLOWED_IMAGE_TYPES
    logger.debug(f"   - Valid: {is_valid}")

    return is_valid


def cleanup_old_files(
    directory: Path,
    hours: int = settings.TEMP_FILE_LIFETIME_HOURS
) -> int:
    """
    清理指定目录中超过指定时间的文件

    Args:
        directory: 要清理的目录
        hours: 文件存活时间（小时）

    Returns:
        删除的文件数量
    """
    logger.debug(f"🧹 [HELPER] cleanup_old_files() called")
    logger.debug(f"   - Directory: {directory}")
    logger.debug(f"   - Max age: {hours} hours")

    if not directory.exists():
        logger.debug(f"   - Directory does not exist, skipping")
        return 0

    cutoff_time = datetime.now() - timedelta(hours=hours)
    logger.debug(f"   - Cutoff time: {cutoff_time}")

    deleted_count = 0
    total_size = 0

    try:
        files = list(directory.iterdir())
        logger.debug(f"   - Found {len(files)} items")

        for file_path in files:
            if file_path.is_file():
                file_mtime = datetime.fromtimestamp(file_path.stat().st_mtime)
                file_size = file_path.stat().st_size

                if file_mtime < cutoff_time:
                    try:
                        file_path.unlink()
                        deleted_count += 1
                        total_size += file_size
                        logger.debug(f"   - Deleted: {file_path.name} ({file_size / 1024:.2f}KB)")
                    except Exception as e:
                        logger.warning(f"   - Failed to delete {file_path.name}: {e}")

        if deleted_count > 0:
            logger.info(f"🧹 [HELPER] Deleted {deleted_count} files ({total_size / 1024:.2f}KB) from {directory.name}")
        else:
            logger.debug(f"   - No files to delete")

    except Exception as e:
        logger.error(f"❌ [HELPER] Error cleaning directory {directory}: {e}")

    return deleted_count


def cleanup_all_temp_files() -> dict:
    """
    清理所有临时文件

    Returns:
        清理统计信息
    """
    logger.info("🧹 [HELPER] cleanup_all_temp_files() called")
    cleanup_start = time.time()

    stats = {
        "upload_dir": 0,
        "temp_dir": 0,
        "total": 0
    }

    stats["upload_dir"] = cleanup_old_files(settings.UPLOAD_DIR)
    stats["temp_dir"] = cleanup_old_files(settings.TEMP_DIR)
    stats["total"] = stats["upload_dir"] + stats["temp_dir"]

    cleanup_time = time.time() - cleanup_start
    logger.info(f"✅ [HELPER] Cleanup completed in {cleanup_time:.2f}s: {stats}")
    return stats


def get_file_size_mb(file_path: str) -> float:
    """
    获取文件大小（MB）

    Args:
        file_path: 文件路径

    Returns:
        文件大小（MB）
    """
    try:
        size_bytes = Path(file_path).stat().st_size
        return size_bytes / (1024 * 1024)
    except Exception:
        return 0.0


def ensure_directory_exists(directory: Path) -> None:
    """
    确保目录存在，不存在则创建

    Args:
        directory: 目录路径
    """
    directory.mkdir(parents=True, exist_ok=True)


def get_relative_path(file_path: Path, base_dir: Path = None) -> str:
    """
    获取相对于base_dir的相对路径

    Args:
        file_path: 文件路径
        base_dir: 基础目录，默认为BASE_DIR

    Returns:
        相对路径字符串
    """
    if base_dir is None:
        base_dir = settings.BASE_DIR

    try:
        return str(file_path.relative_to(base_dir))
    except ValueError:
        return str(file_path)
