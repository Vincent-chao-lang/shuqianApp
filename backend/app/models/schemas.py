#
# schemas.py
# Pydantic数据模型定义
#

from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from enum import Enum
import re


# ============================================
# 枚举类型
# ============================================

class MoodType(str, Enum):
    """情绪类型枚举"""
    WARM = "温暖治愈"
    FRESH = "清新自然"
    PROFESSIONAL = "专业简约"
    PLAYFUL = "活泼可爱"
    ELEGANT = "优雅复古"
    MODERN = "现代时尚"
    ARTISTIC = "艺术文艺"


class LayoutType(str, Enum):
    """布局类型枚举"""
    HORIZONTAL = "left-right"          # 左图右文
    VERTICAL = "top-bottom"            # 上图下文
    CENTERED = "center-focused"        # 居中聚焦
    MOSAIC = "mosaic-grid"             # 拼贴网格
    FULL_BLEED = "full-bleed-image"    # 全出血图片


# ============================================
# 基础模型
# ============================================

class BackgroundType(str, Enum):
    """背景类型"""
    SOLID = "solid"      # 纯色
    GRADIENT = "gradient"  # 渐变
    IMAGE = "image"      # 图片


class GradientDirection(str, Enum):
    """渐变方向"""
    HORIZONTAL = "horizontal"    # 水平渐变
    VERTICAL = "vertical"        # 垂直渐变
    DIAGONAL = "diagonal"        # 对角渐变
    RADIAL = "radial"           # 径向渐变


class GradientBackground(BaseModel):
    """渐变背景"""
    type: BackgroundType = Field(default=BackgroundType.GRADIENT, description="背景类型")
    direction: GradientDirection = Field(default=GradientDirection.VERTICAL, description="渐变方向")
    colors: List[str] = Field(..., min_items=2, max_items=3, description="渐变颜色列表")
    angle: float = Field(default=90.0, ge=0, le=360, description="渐变角度（度）")


class ImageBackground(BaseModel):
    """图片背景"""
    type: BackgroundType = Field(default=BackgroundType.IMAGE, description="背景类型")
    image_path: str = Field(..., description="图片路径")
    opacity: float = Field(default=1.0, ge=0, le=1, description="不透明度")
    fit_mode: str = Field(default="cover", description="填充模式: cover/contain/stretch")


class SolidBackground(BaseModel):
    """纯色背景"""
    type: BackgroundType = Field(default=BackgroundType.SOLID, description="背景类型")
    color: str = Field(..., description="背景颜色（HEX）")


class BackgroundSettings(BaseModel):
    """背景设置"""
    background_type: BackgroundType = Field(..., description="背景类型")
    solid: Optional[SolidBackground] = Field(None, description="纯色背景")
    gradient: Optional[GradientBackground] = Field(None, description="渐变背景")
    image: Optional[ImageBackground] = Field(None, description="图片背景")


class DesignColor(BaseModel):
    """颜色模型"""
    hex: str = Field(..., description="十六进制颜色值，如 #F5F5DC")
    name: str = Field(..., description="颜色名称，如 米白")

    @field_validator("hex")
    @classmethod
    def validate_hex(cls, v: str) -> str:
        """验证十六进制颜色格式"""
        if not re.match(r"^#[0-9A-Fa-f]{6}$", v):
            raise ValueError(f"Invalid hex color format: {v}")
        return v.upper()


class LayoutInfo(BaseModel):
    """布局信息"""
    type: LayoutType = Field(..., description="布局类型")
    confidence: float = Field(..., ge=0, le=1, description="置信度 0-1")
    description: str = Field(..., description="布局描述")


class ColorScheme(BaseModel):
    """配色方案"""
    primary: List[DesignColor] = Field(default_factory=list, description="主色调（1-2个）")
    secondary: List[DesignColor] = Field(default_factory=list, description="辅助色（1-2个）")
    accent: List[DesignColor] = Field(default_factory=list, description="点缀色（1个）")
    neutral: List[DesignColor] = Field(default_factory=list, description="中性色（1-2个）")
    palette_name: str = Field(..., description="配色方案名称")
    mood: str = Field(..., description="整体情绪/氛围")
    harmony: str = Field(..., description="色彩和谐度描述")


class Typography(BaseModel):
    """字体信息"""
    primary_font: str = Field(..., description="主标题字体风格")
    body_font: str = Field(..., description="正文字体风格")
    font_pairs: List[str] = Field(default_factory=list, description="推荐的字体搭配")
    text_color: str = Field(..., description="文字颜色")


class StyleAttributes(BaseModel):
    """风格属性"""
    keywords: List[str] = Field(..., description="风格关键词")
    mood: MoodType = Field(..., description="整体情绪")
    complexity: int = Field(..., ge=1, le=5, description="复杂度等级 1-5")
    aesthetic_tags: List[str] = Field(default_factory=list, description="美学标签")


class DecorativeElements(BaseModel):
    """装饰元素"""
    has_border: bool = Field(default=False, description="是否有边框")
    has_pattern: bool = Field(default=False, description="是否有图案背景")
    has_icon: bool = Field(default=False, description="是否有图标")
    suggested_elements: List[str] = Field(default_factory=list, description="建议添加的装饰元素")


# ============================================
# 请求模型
# ============================================

class AnalyzeReferenceRequest(BaseModel):
    """分析参考图片请求"""
    pass  # 图片通过 multipart/form-data 上传


class GeneratePreviewRequest(BaseModel):
    """生成预览请求"""
    mood: MoodType = Field(..., description="选择的情绪类型")
    complexity: int = Field(..., ge=1, le=5, description="复杂度等级")
    colors: List[str] = Field(..., min_items=1, max_items=4, description="颜色列表")
    layout: LayoutType = Field(..., description="布局类型")


# ============================================
# 富文本相关模型
# ============================================

class TextDirection(str, Enum):
    """文字方向"""
    HORIZONTAL = "horizontal"
    VERTICAL = "vertical"


class TextAlignment(str, Enum):
    """对齐方式"""
    LEFT = "left"
    CENTER = "center"
    RIGHT = "right"


class FontSize(str, Enum):
    """字号大小"""
    SMALL = "small"      # 14-16px
    MEDIUM = "medium"    # 18-24px
    LARGE = "large"      # 28-36px
    EXTRA_LARGE = "xlarge" # 40-48px


class TextPosition(BaseModel):
    """文本区域位置设置"""
    top_margin: int = Field(default=40, ge=0, description="顶部边距（像素）")
    bottom_margin: int = Field(default=40, ge=0, description="底部边距（像素）")
    left_margin: int = Field(default=40, ge=0, description="左侧边距（像素）")
    right_margin: int = Field(default=40, ge=0, description="右侧边距（像素）")
    width: Optional[int] = Field(None, ge=0, description="文本区域宽度（None表示自动计算）")
    height: Optional[int] = Field(None, ge=0, description="文本区域高度（None表示自动计算）")
    alignment: TextAlignment = Field(default=TextAlignment.CENTER, description="对齐方式")
    direction: TextDirection = Field(default=TextDirection.HORIZONTAL, description="文字方向")


class TextStyle(BaseModel):
    """文本样式"""
    font_size: FontSize = Field(default=FontSize.MEDIUM, description="字号大小")
    font_weight: str = Field(default="normal", description="字体粗细: normal/bold")
    font_style: str = Field(default="normal", description="字体样式: normal/italic")
    color: str = Field(default="#333333", description="文字颜色 (HEX)")
    alignment: TextAlignment = Field(default=TextAlignment.CENTER, description="对齐方式")
    direction: TextDirection = Field(default=TextDirection.HORIZONTAL, description="文字方向")


class TextBlock(BaseModel):
    """文本块"""
    text: str = Field(..., description="文本内容")
    style: TextStyle = Field(default_factory=TextStyle, description="文本样式")


class RichTextContent(BaseModel):
    """富文本内容"""
    blocks: List[TextBlock] = Field(..., min_items=1, description="文本块列表")


class GenerateFinalRequest(BaseModel):
    """生成最终书签请求"""
    mood: MoodType
    complexity: int = Field(..., ge=1, le=5)
    colors: List[str] = Field(..., min_items=1, max_items=4)
    layout: LayoutType
    user_photo_path: Optional[str] = Field(None, description="用户照片路径")
    user_text: str = Field(..., min_length=0, max_length=500, description="用户输入的文字（支持富文本JSON）")
    rich_text: Optional[RichTextContent] = Field(None, description="富文本内容（可选）")
    background: Optional[BackgroundSettings] = Field(None, description="背景设置（可选，默认使用第一个颜色作为纯色背景）")
    text_position: Optional[TextPosition] = Field(None, description="文本区域位置设置（可选）")
    show_borders: bool = Field(default=False, description="是否显示边线装饰")


# ============================================
# 响应模型
# ============================================

class ImageAnalysisResult(BaseModel):
    """图片分析结果"""
    layout: LayoutInfo
    colors: ColorScheme
    typography: Typography
    style_attributes: StyleAttributes
    decorative_elements: DecorativeElements
    suggestions: List[str] = Field(default_factory=list, description="改进建议")
    preview: Optional[str] = Field(None, description="AI对图片的描述（Response preview）")
    raw_analysis: Optional[str] = Field(None, description="原始分析文本")


class PreviewGenerationResult(BaseModel):
    """预览生成结果"""
    preview_url: str = Field(..., description="预览图片URL")
    width: int = Field(..., description="预览宽度")
    height: int = Field(..., description="预览高度")


class FinalGenerationResult(BaseModel):
    """最终生成结果"""
    png_url: str = Field(..., description="PNG文件下载URL")
    pdf_url: str = Field(..., description="PDF文件下载URL")
    width: int = Field(..., description="图片宽度（像素）")
    height: int = Field(..., description="图片高度（像素）")
    dpi: int = Field(..., description="输出DPI")


# ============================================
# 通用响应模型
# ============================================

class APIResponse(BaseModel):
    """通用API响应"""
    success: bool = True
    message: str = "操作成功"
    data: Optional[dict] = None


class ErrorResponse(BaseModel):
    """错误响应"""
    success: bool = False
    message: str
    error_code: Optional[str] = None
    details: Optional[str] = None


# ============================================
# 健康检查
# ============================================

class HealthResponse(BaseModel):
    """健康检查响应"""
    status: str = "healthy"
    version: str
    uptime_seconds: float


# ============================================
# 模型管理
# ============================================

class ModelInfo(BaseModel):
    """模型信息"""
    id: str = Field(..., description="模型ID")
    name: str = Field(..., description="模型名称")
    provider: str = Field(..., description="提供商")
    description: str = Field(..., description="模型描述")
    pricing: str = Field(..., description="价格信息")
    features: List[str] = Field(..., description="特性列表")
    is_default: bool = Field(default=False, description="是否为默认模型")


class ModelListResponse(BaseModel):
    """模型列表响应"""
    models: List[ModelInfo]
    default_model: str
    count: int
