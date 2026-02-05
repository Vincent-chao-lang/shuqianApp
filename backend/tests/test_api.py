#
# test_api.py
# API测试示例
#

import pytest
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_root():
    """测试根路径"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Bookmark Designer API"
    assert "version" in data


def test_health_check():
    """测试健康检查"""
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "uptime_seconds" in data


def test_generate_preview():
    """测试预览生成"""
    request_data = {
        "mood": "温暖治愈",
        "complexity": 3,
        "colors": ["#F5F5DC", "#8B7355"],
        "layout": "left-right"
    }

    response = client.post("/api/generate-preview", json=request_data)
    assert response.status_code == 200
    data = response.json()
    assert "preview_url" in data
    assert "width" in data
    assert "height" in data


def test_cleanup_endpoint():
    """测试清理端点"""
    response = client.post("/api/cleanup")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
