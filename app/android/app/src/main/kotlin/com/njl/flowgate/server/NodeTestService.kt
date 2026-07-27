package com.njl.flowgate.server

import com.njl.flowgate.server.dto.NodeDto
import com.njl.flowgate.server.dto.NodeTestResponse
import com.njl.flowgate.server.dto.TestAllProgressResponse
import kotlinx.coroutines.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.net.InetSocketAddress
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * TCP connection latency tester for proxy nodes.
 *
 * Tests connectivity by establishing a raw TCP connection to the node's
 * server:port and measuring the handshake time. This does NOT test
 * actual proxy throughput — only reachability and latency.
 */
class NodeTestService(private val logBuffer: LogBuffer) {

    companion object {
        private const val TAG = "NodeTestService"
        private const val CONNECT_TIMEOUT_MS = 5000
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Active test-all tasks
    private val activeTasks = ConcurrentHashMap<String, TestAllTask>()

    /**
     * Test a single node's TCP latency.
     */
    fun testNode(node: NodeDto): NodeTestResponse {
        return try {
            val start = System.currentTimeMillis()
            val socket = Socket()
            socket.connect(InetSocketAddress(node.server, node.port), CONNECT_TIMEOUT_MS)
            val delay = (System.currentTimeMillis() - start).toInt()
            socket.close()

            logBuffer.add("DEBUG", TAG, "Node ${node.name} (${node.server}:${node.port}) latency: ${delay}ms")
            NodeTestResponse(nodeId = node.id, delay = delay)
        } catch (e: Exception) {
            logBuffer.add("WARN", TAG, "Node ${node.name} test failed: ${e.message}")
            NodeTestResponse(nodeId = node.id, delay = null, error = e.message ?: "Connection failed")
        }
    }

    /**
     * Start a batch test-all task. Returns task ID for progress polling.
     */
    fun startTestAll(nodes: List<NodeDto>): String {
        val taskId = UUID.randomUUID().toString().take(8)
        val task = TestAllTask(taskId = taskId, total = nodes.size)
        activeTasks[taskId] = task

        scope.launch {
            logBuffer.add("INFO", TAG, "Starting test-all: ${nodes.size} nodes, taskId=$taskId")

            // Test in parallel batches of 10
            nodes.chunked(10).forEach { batch ->
                val results = batch.map { node ->
                    async { testNode(node) }
                }.awaitAll()

                synchronized(task.results) {
                    task.results.addAll(results)
                    task.completed += results.size
                }

                // Push SSE progress event
                val progressJson = Json.encodeToString(getProgress(taskId)!!)
                SseEventBus.tryEmit(SseEvent("test-progress", progressJson))
            }

            task.finished = true
            logBuffer.add("INFO", TAG, "Test-all completed: taskId=$taskId, ${task.completed}/${task.total}")

            // Push final event
            SseEventBus.tryEmit(SseEvent("test-complete", """{"taskId":"$taskId"}"""))

            // Clean up after 5 minutes
            delay(300_000)
            activeTasks.remove(taskId)
        }

        return taskId
    }

    /**
     * Get progress of a test-all task.
     */
    fun getProgress(taskId: String): TestAllProgressResponse? {
        val task = activeTasks[taskId] ?: return null
        synchronized(task.results) {
            return TestAllProgressResponse(
                taskId = taskId,
                completed = task.completed,
                total = task.total,
                results = task.results.toList()
            )
        }
    }

    fun destroy() {
        scope.cancel()
        activeTasks.clear()
    }
}

private class TestAllTask(
    val taskId: String,
    val total: Int,
    var completed: Int = 0,
    var finished: Boolean = false,
    val results: MutableList<NodeTestResponse> = mutableListOf()
)
