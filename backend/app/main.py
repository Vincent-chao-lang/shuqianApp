#
# main.py
# FastAPI应用主入口
#

import sys
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from loguru import logger

from app.core.config import settings
from app.api.routes import router
from app.utils.helpers import cleanup_all_temp_files


# ============================================
# 配置日志
# ============================================

# 移除默认的stderr处理器
logger.remove()

# 添加控制台日志（带颜色）
logger.add(
    sys.stderr,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
    level=settings.LOG_LEVEL,
    colorize=True
)

# 添加文件日志
logger.add(
    settings.LOG_DIR / "app_{time:YYYY-MM-DD}.log",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{function}:{line} - {message}",
    level=settings.LOG_LEVEL,
    rotation="00:00",  # 每天午夜轮换
    retention="30 days",  # 保留30天
    compression="zip",  # 压缩旧日志
    encoding="utf-8"
)


# ============================================
# 生命周期管理
# ============================================

# 定时任务调度器
scheduler = AsyncIOScheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时执行
    logger.info("=" * 60)
    logger.info(f"🚀 {settings.PROJECT_NAME} v{settings.VERSION} 启动中...")
    logger.info(f"📁 工作目录: {settings.BASE_DIR}")
    logger.info(f"🎨 Claude模型: {settings.CLAUDE_MODEL}")
    logger.info(f"📏 书签尺寸: {settings.BOOKMARK_WIDTH_MM}x{settings.BOOKMARK_HEIGHT_MM}mm")
    logger.info("=" * 60)

    # 启动定时清理任务
    scheduler.add_job(
        cleanup_all_temp_files,
        "interval",
        minutes=settings.CLEANUP_INTERVAL_MINUTES,
        id="cleanup_temp_files",
        replace_existing=True
    )
    scheduler.start()
    logger.info(f"🧹 定时清理任务已启动（间隔: {settings.CLEANUP_INTERVAL_MINUTES}分钟）")

    # 初始清理
    cleanup_stats = cleanup_all_temp_files()
    logger.info(f"🧹 初始清理完成: {cleanup_stats}")

    yield

    # 关闭时执行
    logger.info("🛑 应用关闭中...")
    scheduler.shutdown()
    logger.info("✅ 应用已安全关闭")


# ============================================
# 创建FastAPI应用
# ============================================

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="AI书签设计API - 使用Claude Vision分析参考图片并生成个性化书签",
    lifespan=lifespan,
    docs_url="/docs",  # Swagger UI
    redoc_url="/redoc",  # ReDoc
)


# ============================================
# 全局异常处理器
# ============================================

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """处理Pydantic验证错误，返回详细错误信息"""
    logger.error("=" * 60)
    logger.error("❌ [VALIDATION] Request validation failed")
    logger.error(f"❌ [VALIDATION] URL: {request.url}")
    logger.error(f"❌ [VALIDATION] Method: {request.method}")
    logger.error(f"❌ [VALIDATION] Errors: {exc.errors()}")
    # 不记录 exc.body，因为 FormData 对象不能被序列化
    logger.error("=" * 60)

    return JSONResponse(
        status_code=422,
        content={
            "success": False,
            "message": "Validation error",
            "errors": exc.errors()
        }
    )


# ============================================
# 配置CORS
# ============================================

# 开发模式：允许所有本地源
if settings.ALLOW_LOCAL_DEV:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # 开发模式允许所有源
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    logger.info("🔓 CORS已配置为开发模式（允许所有源）")
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


# ============================================
# 注册路由
# ============================================

app.include_router(
    router,
    prefix=settings.API_V1_STR,
    tags=["API"]
)


# ============================================
# 根路径
# ============================================

@app.get("/")
async def root():
    """根路径，返回API信息"""
    return {
        "name": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "status": "running",
        "docs": "/docs",
        "health": f"{settings.API_V1_STR}/health"
    }


# ============================================
# 运行入口（仅用于开发）
# ============================================

if __name__ == "__main__":
    import uvicorn

    logger.info("🔧 开发模式启动")
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.RELOAD,
        log_level="info"
    )
