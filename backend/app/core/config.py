#
# config.py
# 配置管理模块
#

from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional
import os
from pathlib import Path


class Settings(BaseSettings):
    """应用配置类，从环境变量读取配置"""

    # API配置
    API_V1_STR: str = "/api"
    PROJECT_NAME: str = "Bookmark Designer API"
    VERSION: str = "1.0.0"

    # 服务器配置
    HOST: str = Field(default="0.0.0.0", description="服务器监听地址")
    PORT: int = Field(default=8000, description="服务器端口")
    RELOAD: bool = Field(default=True, description="开发模式自动重载")

    # CORS配置
    CORS_ORIGINS: list[str] = Field(
        default=[
            "http://localhost:3000",
            "http://localhost:8000",
            "http://127.0.0.1:8000",
            # iOS模拟器支持
            "http://localhost:5000",
            "http://127.0.0.1:5000",
        ],
        description="允许的CORS源"
    )

    # 允许所有本地开发源（开发模式）
    ALLOW_LOCAL_DEV: bool = Field(default=True, description="允许本地开发源")

    # Claude API配置
    ANTHROPIC_API_KEY: str = Field(default="", description="Anthropic API密钥")
    CLAUDE_MODEL: str = Field(default="claude-3-5-sonnet-20241022", description="Claude模型版本")
    CLAUDE_MAX_TOKENS: int = Field(default=4096, description="Claude最大token数")

    # GLM API配置
    GLM_API_KEY: str = Field(default="", description="智谱AI GLM API密钥")
    GLM_MODEL: str = Field(default="glm-4v-flash", description="GLM模型版本")

    # Qwen API配置
    QWEN_API_KEY: str = Field(default="", description="阿里云Qwen API密钥")
    QWEN_MODEL: str = Field(default="qwen-vl-plus", description="Qwen模型版本")

    # 默认视觉模型选择
    DEFAULT_VISION_MODEL: str = Field(default="glm", description="默认视觉模型 (glm/qwen/claude)")

    # 文件上传配置
    MAX_UPLOAD_SIZE: int = Field(default=10 * 1024 * 1024, description="最大上传大小（字节）")
    ALLOWED_IMAGE_TYPES: list[str] = Field(
        default=["image/jpeg", "image/png", "image/webp", "image/gif"],
        description="允许的图片类型"
    )

    # 文件存储配置
    BASE_DIR: Path = Field(default=Path(__file__).resolve().parent.parent.parent)
    UPLOAD_DIR: Path = Field(default=Path("uploads"))
    DOWNLOAD_DIR: Path = Field(default=Path("downloads"))
    TEMP_DIR: Path = Field(default=Path("temp"))

    # 书签生成配置
    BOOKMARK_WIDTH_MM: float = Field(default=60, description="书签宽度（毫米）")
    BOOKMARK_HEIGHT_MM: float = Field(default=180, description="书签高度（毫米）")
    BLEED_MM: float = Field(default=3, description="出血区（毫米）")
    SAFE_MARGIN_MM: float = Field(default=5, description="安全边距（毫米）")

    # DPI配置
    PREVIEW_DPI: int = Field(default=72, description="预览DPI")
    FINAL_DPI: int = Field(default=300, description="最终输出DPI")

    # 临时文件清理配置
    TEMP_FILE_LIFETIME_HOURS: int = Field(default=1, description="临时文件存活时间（小时）")
    CLEANUP_INTERVAL_MINUTES: int = Field(default=30, description="清理间隔（分钟）")

    # 日志配置
    LOG_LEVEL: str = Field(default="INFO", description="日志级别")
    LOG_DIR: Path = Field(default=Path("logs"))

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True
        extra = "ignore"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # 确保所有目录都是绝对路径
        self.UPLOAD_DIR = self.BASE_DIR / self.UPLOAD_DIR
        self.DOWNLOAD_DIR = self.BASE_DIR / self.DOWNLOAD_DIR
        self.TEMP_DIR = self.BASE_DIR / self.TEMP_DIR
        self.LOG_DIR = self.BASE_DIR / self.LOG_DIR
        # 创建必要的目录
        self._create_directories()

    def _create_directories(self):
        """创建必要的目录"""
        for dir_path in [self.UPLOAD_DIR, self.DOWNLOAD_DIR, self.TEMP_DIR, self.LOG_DIR]:
            dir_path.mkdir(parents=True, exist_ok=True)

    @property
    def bookmark_size_px_preview(self) -> tuple[int, int]:
        """获取预览尺寸（像素）"""
        width_px = int(self.mm_to_px(self.BOOKMARK_WIDTH_MM, self.PREVIEW_DPI))
        height_px = int(self.mm_to_px(self.BOOKMARK_HEIGHT_MM, self.PREVIEW_DPI))
        return (width_px, height_px)

    @property
    def bookmark_size_px_final(self) -> tuple[int, int]:
        """获取最终输出尺寸（像素）"""
        width_px = int(self.mm_to_px(self.BOOKMARK_WIDTH_MM, self.FINAL_DPI))
        height_px = int(self.mm_to_px(self.BOOKMARK_HEIGHT_MM, self.FINAL_DPI))
        return (width_px, height_px)

    @property
    def bleed_px_final(self) -> int:
        """获取最终输出的出血像素"""
        return int(self.mm_to_px(self.BLEED_MM, self.FINAL_DPI))

    @property
    def safe_margin_px_final(self) -> int:
        """获取最终输出的安全边距像素"""
        return int(self.mm_to_px(self.SAFE_MARGIN_MM, self.FINAL_DPI))

    @staticmethod
    def mm_to_px(mm: float, dpi: int) -> float:
        """毫米转像素"""
        return (mm / 25.4) * dpi


# 全局配置实例
settings = Settings()
