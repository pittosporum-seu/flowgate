"""
FlowGate API 集成测试
=====================
通过 adb forward 将设备上的 Ktor Server 端口映射到本地，
然后用 HTTP 请求验证所有 REST 端点的可用性。

前置条件:
  1. Android 设备通过 USB 连接且 FlowGate 已启动
  2. adb forward tcp:19840 tcp:19840

运行:
  cd flowgate/tests
  python -m pytest api/ -v
"""

import time
import uuid
import pytest
import requests

BASE_URL = "http://127.0.0.1:19840/api/v1"
TIMEOUT = 10


# ─── Fixtures ─────────────────────────────────────────────────────────────


@pytest.fixture(scope="session", autouse=True)
def check_server():
    """确保 API Server 可达，否则跳过全部测试"""
    try:
        r = requests.get(f"{BASE_URL}/health", timeout=3)
        assert r.status_code == 200
    except requests.ConnectionError:
        pytest.skip(
            "FlowGate API Server 不可达 (127.0.0.1:19840)。"
            "请确保: 1) 设备已连接 2) adb forward tcp:19840 tcp:19840 3) App 已启动"
        )


@pytest.fixture
def sample_node():
    """创建一个测试节点，测试结束后删除"""
    node = {
        "id": f"test-{uuid.uuid4().hex[:8]}",
        "name": "Test Node",
        "type": "trojan",
        "server": "1.2.3.4",
        "port": 443,
        "password": "test-pass",
        "sni": "example.com",
        "allowInsecure": True,
    }
    r = requests.post(f"{BASE_URL}/nodes", json=node, timeout=TIMEOUT)
    assert r.status_code == 201, f"Failed to create node: {r.text}"
    created = r.json()["data"]
    yield created
    # cleanup
    requests.delete(f"{BASE_URL}/nodes/{created['id']}", timeout=TIMEOUT)


@pytest.fixture
def sample_subscription():
    """创建一个测试订阅，测试结束后删除"""
    sub = {
        "name": "Test Sub",
        "url": "https://example.com/sub",
        "autoUpdate": False,
    }
    r = requests.post(f"{BASE_URL}/subscriptions", json=sub, timeout=TIMEOUT)
    assert r.status_code == 201, f"Failed to create subscription: {r.text}"
    created = r.json()["data"]
    yield created
    # cleanup
    requests.delete(
        f"{BASE_URL}/subscriptions/{created['id']}",
        params={"deleteNodes": "true"},
        timeout=TIMEOUT,
    )


# ─── Health ───────────────────────────────────────────────────────────────


class TestHealth:
    def test_health_check(self):
        r = requests.get(f"{BASE_URL}/health", timeout=TIMEOUT)
        assert r.status_code == 200
        body = r.json()
        assert body["ok"] is True
        assert body["data"]["status"] == "ok"


# ─── System ───────────────────────────────────────────────────────────────


class TestSystem:
    def test_system_info(self):
        r = requests.get(f"{BASE_URL}/system/info", timeout=TIMEOUT)
        assert r.status_code == 200
        data = r.json()["data"]
        assert "version" in data
        assert "platform" in data
        assert data["platform"] == "android"
        assert data["apiPort"] == 19840

    def test_system_logs(self):
        r = requests.get(f"{BASE_URL}/system/logs", params={"limit": 10}, timeout=TIMEOUT)
        assert r.status_code == 200
        data = r.json()["data"]
        assert "logs" in data
        assert "total" in data
        assert isinstance(data["logs"], list)

    def test_system_logs_limit(self):
        r = requests.get(f"{BASE_URL}/system/logs", params={"limit": 3}, timeout=TIMEOUT)
        assert r.status_code == 200
        logs = r.json()["data"]["logs"]
        assert len(logs) <= 3


# ─── VPN ──────────────────────────────────────────────────────────────────


class TestVpn:
    def test_vpn_status(self):
        r = requests.get(f"{BASE_URL}/vpn/status", timeout=TIMEOUT)
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["state"] in ("connected", "connecting", "disconnected", "disconnecting")
        assert "duration" in data
        assert "uploadSpeed" in data
        assert "downloadSpeed" in data

    def test_vpn_stop_when_disconnected(self):
        """停止操作在未连接时应安全返回"""
        r = requests.post(f"{BASE_URL}/vpn/stop", timeout=TIMEOUT)
        assert r.status_code == 200
        assert r.json()["ok"] is True


# ─── Nodes CRUD ───────────────────────────────────────────────────────────


class TestNodesCrud:
    def test_list_nodes(self):
        r = requests.get(f"{BASE_URL}/nodes", timeout=TIMEOUT)
        assert r.status_code == 200
        data = r.json()["data"]
        assert "nodes" in data
        assert "total" in data
        assert isinstance(data["nodes"], list)

    def test_create_node(self, sample_node):
        assert sample_node["name"] == "Test Node"
        assert sample_node["type"] == "trojan"
        assert sample_node["server"] == "1.2.3.4"
        assert sample_node["port"] == 443

    def test_get_node_by_id(self, sample_node):
        r = requests.get(f"{BASE_URL}/nodes/{sample_node['id']}", timeout=TIMEOUT)
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["id"] == sample_node["id"]
        assert data["name"] == "Test Node"

    def test_get_node_not_found(self):
        r = requests.get(f"{BASE_URL}/nodes/nonexistent-id", timeout=TIMEOUT)
        assert r.status_code == 404
        assert r.json()["ok"] is False

    def test_delete_node(self):
        # 先创建
        node = {
            "id": f"del-{uuid.uuid4().hex[:8]}",
            "name": "To Delete",
            "type": "vless",
            "server": "5.6.7.8",
            "port": 8443,
            "password": "uuid-here",
        }
        r = requests.post(f"{BASE_URL}/nodes", json=node, timeout=TIMEOUT)
        assert r.status_code == 201
        node_id = r.json()["data"]["id"]

        # 删除
        r = requests.delete(f"{BASE_URL}/nodes/{node_id}", timeout=TIMEOUT)
        assert r.status_code == 200

        # 确认已删除
        r = requests.get(f"{BASE_URL}/nodes/{node_id}", timeout=TIMEOUT)
        assert r.status_code == 404

    def test_delete_node_not_found(self):
        r = requests.delete(f"{BASE_URL}/nodes/nonexistent-id", timeout=TIMEOUT)
        assert r.status_code == 404


# ─── Nodes Import ─────────────────────────────────────────────────────────


class TestNodesImport:
    def test_import_trojan_link(self):
        content = "trojan://pass123@10.0.0.1:443?allowInsecure=1&sni=test.com#ImportTest"
        r = requests.post(
            f"{BASE_URL}/nodes/import",
            json={"content": content, "type": "raw"},
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["imported"] == 1
        node = data["nodes"][0]
        assert node["type"] == "trojan"
        assert node["server"] == "10.0.0.1"
        assert node["port"] == 443
        assert node["name"] == "ImportTest"
        # cleanup
        requests.delete(f"{BASE_URL}/nodes/{node['id']}", timeout=TIMEOUT)

    def test_import_vless_link(self):
        content = "vless://my-uuid@10.0.0.2:8443?type=ws&path=%2Fws&host=cdn.com#VlessNode"
        r = requests.post(
            f"{BASE_URL}/nodes/import",
            json={"content": content, "type": "raw"},
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["imported"] == 1
        node = data["nodes"][0]
        assert node["type"] == "vless"
        assert node["server"] == "10.0.0.2"
        assert node["network"] == "ws"
        # cleanup
        requests.delete(f"{BASE_URL}/nodes/{node['id']}", timeout=TIMEOUT)

    def test_import_multiple_links(self):
        content = "\n".join([
            "trojan://p1@1.1.1.1:443#Node1",
            "trojan://p2@2.2.2.2:443#Node2",
            "vless://uuid@3.3.3.3:8443#Node3",
        ])
        r = requests.post(
            f"{BASE_URL}/nodes/import",
            json={"content": content, "type": "raw"},
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["imported"] == 3
        # cleanup
        for node in data["nodes"]:
            requests.delete(f"{BASE_URL}/nodes/{node['id']}", timeout=TIMEOUT)

    def test_import_base64(self):
        import base64

        links = "trojan://b64pass@9.9.9.9:443#B64Node\nvless://b64uuid@8.8.8.8:443#B64Vless"
        encoded = base64.b64encode(links.encode()).decode()
        r = requests.post(
            f"{BASE_URL}/nodes/import",
            json={"content": encoded, "type": "base64"},
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["imported"] == 2
        # cleanup
        for node in data["nodes"]:
            requests.delete(f"{BASE_URL}/nodes/{node['id']}", timeout=TIMEOUT)

    def test_import_invalid_content(self):
        r = requests.post(
            f"{BASE_URL}/nodes/import",
            json={"content": "this is not a valid link", "type": "raw"},
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["imported"] == 0


# ─── Nodes Test (Latency) ────────────────────────────────────────────────


class TestNodesLatency:
    def test_single_node_test(self, sample_node):
        """测速可能失败（服务器不可达），但 API 应正常返回"""
        r = requests.post(
            f"{BASE_URL}/nodes/{sample_node['id']}/test", timeout=30
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["nodeId"] == sample_node["id"]
        # delay 为 null 表示失败，整数表示成功
        assert data["delay"] is None or isinstance(data["delay"], int)

    def test_test_all(self, sample_node):
        r = requests.post(f"{BASE_URL}/nodes/test-all", timeout=TIMEOUT)
        assert r.status_code == 200
        data = r.json()["data"]
        assert "taskId" in data
        assert data["total"] >= 1

        # 轮询进度
        task_id = data["taskId"]
        for _ in range(10):
            time.sleep(1)
            r = requests.get(
                f"{BASE_URL}/nodes/test-all/{task_id}", timeout=TIMEOUT
            )
            if r.status_code == 200:
                progress = r.json()["data"]
                if progress["completed"] >= progress["total"]:
                    break
        # 不强制断言完成（网络可能慢），只验证 API 可用
        assert r.status_code == 200

    def test_test_progress_not_found(self):
        r = requests.get(
            f"{BASE_URL}/nodes/test-all/nonexistent-task", timeout=TIMEOUT
        )
        assert r.status_code == 404


# ─── Subscriptions CRUD ──────────────────────────────────────────────────


class TestSubscriptionsCrud:
    def test_list_subscriptions(self):
        r = requests.get(f"{BASE_URL}/subscriptions", timeout=TIMEOUT)
        assert r.status_code == 200
        assert r.json()["ok"] is True

    def test_create_subscription(self, sample_subscription):
        assert sample_subscription["name"] == "Test Sub"
        assert sample_subscription["url"] == "https://example.com/sub"

    def test_get_subscription_by_id(self, sample_subscription):
        r = requests.get(
            f"{BASE_URL}/subscriptions/{sample_subscription['id']}", timeout=TIMEOUT
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["id"] == sample_subscription["id"]

    def test_update_subscription(self, sample_subscription):
        r = requests.put(
            f"{BASE_URL}/subscriptions/{sample_subscription['id']}",
            json={"name": "Renamed Sub", "autoUpdate": True},
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["name"] == "Renamed Sub"
        assert data["autoUpdate"] is True

    def test_delete_subscription(self):
        # 创建
        r = requests.post(
            f"{BASE_URL}/subscriptions",
            json={"name": "To Delete", "url": "https://del.com/sub"},
            timeout=TIMEOUT,
        )
        assert r.status_code == 201
        sub_id = r.json()["data"]["id"]

        # 删除
        r = requests.delete(f"{BASE_URL}/subscriptions/{sub_id}", timeout=TIMEOUT)
        assert r.status_code == 200

        # 确认
        r = requests.get(f"{BASE_URL}/subscriptions/{sub_id}", timeout=TIMEOUT)
        assert r.status_code == 404

    def test_subscription_not_found(self):
        r = requests.get(f"{BASE_URL}/subscriptions/nonexistent", timeout=TIMEOUT)
        assert r.status_code == 404

    def test_create_subscription_missing_url(self):
        r = requests.post(
            f"{BASE_URL}/subscriptions",
            json={"name": "No URL", "url": ""},
            timeout=TIMEOUT,
        )
        assert r.status_code == 400

    def test_refresh_subscription(self, sample_subscription):
        r = requests.post(
            f"{BASE_URL}/subscriptions/{sample_subscription['id']}/update",
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert "nodesAdded" in data


# ─── Routing ──────────────────────────────────────────────────────────────


class TestRouting:
    def test_get_routing(self):
        r = requests.get(f"{BASE_URL}/routing", timeout=TIMEOUT)
        assert r.status_code == 200
        data = r.json()["data"]
        assert "domainStrategy" in data
        assert "rules" in data
        assert "bypassLan" in data

    def test_update_routing_partial(self):
        """部分更新：只改 bypassChina"""
        r = requests.put(
            f"{BASE_URL}/routing",
            json={"bypassChina": True},
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["bypassChina"] is True

        # 恢复
        requests.put(f"{BASE_URL}/routing", json={"bypassChina": False}, timeout=TIMEOUT)

    def test_update_routing_domain_strategy(self):
        r = requests.put(
            f"{BASE_URL}/routing",
            json={"domainStrategy": "IPOnDemand"},
            timeout=TIMEOUT,
        )
        assert r.status_code == 200
        assert r.json()["data"]["domainStrategy"] == "IPOnDemand"

        # 恢复
        requests.put(
            f"{BASE_URL}/routing",
            json={"domainStrategy": "IPIfNonMatch"},
            timeout=TIMEOUT,
        )
