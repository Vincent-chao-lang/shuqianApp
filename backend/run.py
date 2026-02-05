#!/usr/bin/env python3
#
# run.py
# 应用启动脚本
#

import uvicorn
from loguru import logger

from app.core.config import settings


def main():
    """主函数"""
    logger.info("🚀 启动书签设计API服务器...")
    logger.info(f"🌐 服务地址: http://{settings.HOST}:{settings.PORT}")
    logger.info(f"📚 API文档: http://{settings.HOST}:{settings.PORT}/docs")

    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.RELOAD,
        log_level=settings.LOG_LEVEL.lower(),
        access_log=True
    )


if __name__ == "__main__":
    main()
