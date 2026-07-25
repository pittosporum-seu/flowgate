package com.v2ray.ang.ui

import android.content.Intent
import android.content.res.ColorStateList
import android.os.Bundle
import android.view.Gravity
import android.view.inputmethod.EditorInfo
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.core.view.setPadding
import androidx.lifecycle.lifecycleScope
import com.google.android.material.card.MaterialCardView
import com.v2ray.ang.R
import com.v2ray.ang.ai.FlowAiAutonomy
import com.v2ray.ang.ai.FlowAiChatMessage
import com.v2ray.ang.ai.FlowAiClient
import com.v2ray.ang.ai.FlowAiLogCollector
import com.v2ray.ang.ai.FlowAiPlan
import com.v2ray.ang.ai.FlowAiPlanApplier
import com.v2ray.ang.ai.FlowAiProfileManager
import com.v2ray.ang.ai.FlowAiSecretStore
import com.v2ray.ang.ai.FlowAiToolMode
import com.v2ray.ang.databinding.ActivityFlowAiAssistantBinding
import com.v2ray.ang.extension.toast
import com.v2ray.ang.handler.SettingsChangeManager
import com.v2ray.ang.util.JsonUtil
import kotlinx.coroutines.launch

class AiRoutingAssistantActivity : BaseActivity() {
    private val binding by lazy { ActivityFlowAiAssistantBinding.inflate(layoutInflater) }
    private var currentPlan: FlowAiPlan? = null
    private var rawDetails: String = ""
    private var detailsVisible = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FlowAiProfileManager.ensureDefaults()
        setContentViewWithToolbar(binding.root, showHomeAsUp = true, title = getString(R.string.flow_ai_assistant_title))

        binding.btnModels.setOnClickListener { startActivity(Intent(this, AiModelLibraryActivity::class.java)) }
        binding.modelCard.setOnClickListener { startActivity(Intent(this, AiModelLibraryActivity::class.java)) }
        binding.btnAnalyze.setOnClickListener { sendMessage(getString(R.string.flow_ai_chat_user_recent), null) }
        binding.btnChatgptDiagnose.setOnClickListener { sendMessage(getString(R.string.flow_ai_chat_user_chatgpt), "chatgpt") }
        binding.btnAutonomy.setOnClickListener { showAutonomyDialog() }
        binding.btnApplyPlan.setOnClickListener { applyCurrentPlan() }
        binding.btnToggleDetails.setOnClickListener { toggleDetails() }
        binding.btnSend.setOnClickListener { sendTypedMessage() }
        binding.etChat.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEND) {
                sendTypedMessage()
                true
            } else {
                false
            }
        }

        renderHeader()
        renderInitialChat()
    }

    override fun onResume() {
        super.onResume()
        renderHeader()
    }

    private fun renderHeader() {
        val profile = FlowAiProfileManager.getDefaultProfile()
        val fallback = FlowAiProfileManager.getFallbackProfile()
        binding.tvActiveModel.text = getString(
            R.string.flow_ai_active_model,
            profile?.name ?: getString(R.string.flow_value_empty),
            profile?.model ?: getString(R.string.flow_value_empty)
        )
        val toolMode = profile?.toolMode?.let { toolModeText(FlowAiToolMode.fromValue(it)) }
            ?: getString(R.string.flow_ai_tool_mode_auto)
        binding.tvAiMode.text = getString(
            R.string.flow_ai_active_mode,
            autonomyText(FlowAiProfileManager.getAutonomy()),
            fallback?.name ?: getString(R.string.flow_value_empty)
        ) + "\n" + getString(R.string.flow_ai_tool_mode_label, toolMode)
        binding.btnModels.text = if (profile == null) {
            getString(R.string.flow_ai_open_models)
        } else {
            getString(R.string.flow_ai_change_model)
        }
        binding.btnAutonomy.text = getString(
            R.string.flow_ai_autonomy_button,
            autonomyText(FlowAiProfileManager.getAutonomy())
        )
    }

    private fun renderInitialChat() {
        val history = FlowAiProfileManager.getChatHistory()
        if (history.isEmpty()) {
            addChatBubble(getString(R.string.flow_ai_chat_welcome), isUser = false)
        } else {
            history.forEach { addChatBubble(it.text, isUser = it.role == "user", isError = it.error != null) }
        }
    }

    private fun sendTypedMessage() {
        val text = binding.etChat.text?.toString().orEmpty().trim()
        if (text.isBlank()) {
            toast(R.string.flow_ai_chat_empty_input)
            return
        }
        binding.etChat.setText("")
        sendMessage(text, null)
    }

    private fun sendMessage(userText: String, focus: String?) {
        val profile = FlowAiProfileManager.getDefaultProfile()
        if (profile == null || !FlowAiSecretStore.hasApiKey(this, profile.id)) {
            toast(R.string.flow_ai_need_key)
            startActivity(Intent(this, AiModelLibraryActivity::class.java))
            return
        }

        val historyBefore = FlowAiProfileManager.getChatHistory()
        FlowAiProfileManager.appendChat(FlowAiChatMessage(role = "user", text = userText))
        addChatBubble(userText, isUser = true)
        binding.actionList.removeAllViews()
        binding.btnApplyPlan.isVisible = false
        currentPlan = null
        showLoading()
        addChatBubble(getString(R.string.flow_ai_chat_collecting), isUser = false)

        val input = FlowAiLogCollector.collect(this, focus)
        rawDetails = buildString {
            if (focus == "chatgpt") {
                append(FlowAiLogCollector.chatGptDiagnostic(this@AiRoutingAssistantActivity)).append("\n\n")
            }
            append(getString(R.string.flow_ai_observation_summary, input.installedApps.size, input.recentLogs.size, input.selectedApps.size))
            append("\n")
            append(JsonUtil.toJsonPretty(input)?.take(3500).orEmpty())
        }
        binding.tvRawDetails.text = rawDetails

        lifecycleScope.launch {
            val result = FlowAiClient.chat(this@AiRoutingAssistantActivity, userText, input, historyBefore)
            hideLoading()
            if (!result.success) {
                val message = getString(R.string.flow_ai_chat_failed, result.message.orEmpty())
                FlowAiProfileManager.appendChat(FlowAiChatMessage(role = "assistant", text = message, error = result.message))
                addChatBubble(message, isUser = false, isError = true)
                return@launch
            }

            val parsed = FlowAiPlanApplier.parse(result.content)
            if (parsed.success && parsed.plan != null) {
                currentPlan = parsed.plan
                val reply = parsed.plan.summary.ifBlank { getString(R.string.flow_ai_plan_empty) }
                FlowAiProfileManager.appendChat(
                    FlowAiChatMessage(
                        role = "assistant",
                        text = reply,
                        planSummary = reply
                    )
                )
                addChatBubble(reply, isUser = false)
                if (parsed.plan.actions.isNotEmpty()) {
                    addChatBubble(getString(R.string.flow_ai_chat_plan_ready, parsed.plan.actions.size), isUser = false)
                    renderActions(parsed.plan)
                }
                val autonomy = FlowAiProfileManager.getAutonomy()
                if (shouldAutoApply(parsed.plan, autonomy)) {
                    applyPlanNow(parsed.plan)
                    addChatBubble(getString(R.string.flow_ai_auto_applied), isUser = false)
                } else if (parsed.plan.actions.isNotEmpty()) {
                    binding.btnApplyPlan.isVisible = true
                }
            } else {
                val reply = result.content.orEmpty().ifBlank { getString(R.string.flow_ai_plan_empty) }
                FlowAiProfileManager.appendChat(FlowAiChatMessage(role = "assistant", text = reply))
                addChatBubble(reply, isUser = false)
            }
        }
    }

    private fun addChatBubble(text: String, isUser: Boolean, isError: Boolean = false) {
        val wrapper = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = if (isUser) Gravity.END else Gravity.START
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.setMargins(0, 0, 0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp10))
            layoutParams = lp
        }
        val bubbleMaxWidth = (resources.displayMetrics.widthPixels * 0.82f).toInt()
        val bubble = TextView(this).apply {
            this.text = text
            setTextColor(
                ContextCompat.getColor(
                    this@AiRoutingAssistantActivity,
                    when {
                        isUser -> R.color.md_theme_onPrimary
                        isError -> R.color.flow_danger
                        else -> R.color.flow_text_primary
                    }
                )
            )
            textSize = 14f
            setLineSpacing(2f, 1.0f)
            maxWidth = bubbleMaxWidth
            background = ContextCompat.getDrawable(
                this@AiRoutingAssistantActivity,
                if (isUser) R.drawable.flow_chat_user_bubble else R.drawable.flow_chat_assistant_bubble
            )
            setPadding(resources.getDimensionPixelSize(R.dimen.padding_spacing_dp14))
        }
        wrapper.addView(bubble)
        val insertIndex = binding.messageList.indexOfChild(binding.tvRawDetails).coerceAtLeast(0)
        binding.messageList.addView(wrapper, insertIndex)
        binding.chatScroll.post { binding.chatScroll.fullScroll(android.view.View.FOCUS_DOWN) }
    }

    private fun applyCurrentPlan() {
        val plan = currentPlan ?: return
        val autonomy = FlowAiProfileManager.getAutonomy()
        if (autonomy == FlowAiAutonomy.PREVIEW) {
            AlertDialog.Builder(this)
                .setTitle(R.string.flow_ai_apply_plan)
                .setMessage(R.string.flow_ai_apply_confirm)
                .setPositiveButton(android.R.string.ok) { _, _ -> applyPlanNow(plan) }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
        } else {
            applyPlanNow(plan)
        }
    }

    private fun applyPlanNow(plan: FlowAiPlan) {
        val result = FlowAiPlanApplier.apply(this, plan)
        if (!result.success) {
            toast(getString(R.string.flow_ai_apply_failed, result.message.orEmpty()))
            return
        }
        SettingsChangeManager.makeRestartService()
        setResult(RESULT_OK)
        toast(getString(R.string.flow_ai_apply_success, result.appliedCount))
        binding.btnApplyPlan.isVisible = false
    }

    private fun shouldAutoApply(plan: FlowAiPlan, autonomy: FlowAiAutonomy): Boolean {
        return when (autonomy) {
            FlowAiAutonomy.PREVIEW -> false
            FlowAiAutonomy.FULL_AUTO -> true
            FlowAiAutonomy.SAFE_AUTO -> plan.actions.all {
                it.risk.equals("low", ignoreCase = true) && it.confidence >= 0.72
            }
        }
    }

    private fun showAutonomyDialog() {
        val modes = arrayOf(FlowAiAutonomy.PREVIEW, FlowAiAutonomy.SAFE_AUTO, FlowAiAutonomy.FULL_AUTO)
        AlertDialog.Builder(this)
            .setTitle(R.string.flow_ai_autonomy_title)
            .setItems(modes.map { autonomyText(it) }.toTypedArray()) { _, which ->
                FlowAiProfileManager.setAutonomy(modes[which])
                renderHeader()
            }
            .show()
    }

    private fun renderActions(plan: FlowAiPlan) {
        binding.actionList.removeAllViews()
        plan.actions.forEachIndexed { index, action ->
            binding.actionList.addView(MaterialCardView(this).apply {
                radius = resources.getDimension(R.dimen.padding_spacing_dp20)
                strokeWidth = 1
                strokeColor = ContextCompat.getColor(this@AiRoutingAssistantActivity, R.color.flow_line)
                setCardBackgroundColor(ContextCompat.getColor(this@AiRoutingAssistantActivity, R.color.flow_glass_high))
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                lp.setMargins(0, 0, 0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp8))
                layoutParams = lp

                addView(LinearLayout(this@AiRoutingAssistantActivity).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(resources.getDimensionPixelSize(R.dimen.padding_spacing_dp16))

                    addView(LinearLayout(this@AiRoutingAssistantActivity).apply {
                        orientation = LinearLayout.HORIZONTAL
                        gravity = Gravity.CENTER_VERTICAL
                        addView(TextView(this@AiRoutingAssistantActivity).apply {
                            text = getString(
                                R.string.flow_ai_action_title,
                                index + 1,
                                action.type,
                                outboundText(action.outboundTag)
                            )
                            setTextColor(ContextCompat.getColor(this@AiRoutingAssistantActivity, R.color.flow_text_primary))
                            textSize = 15f
                            setTypeface(typeface, android.graphics.Typeface.BOLD)
                            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                        })
                        addView(TextView(this@AiRoutingAssistantActivity).apply {
                            text = riskText(action.risk)
                            background = ContextCompat.getDrawable(this@AiRoutingAssistantActivity, riskBackground(action.risk))
                            backgroundTintList = ColorStateList.valueOf(ContextCompat.getColor(this@AiRoutingAssistantActivity, riskTint(action.risk)))
                            setTextColor(ContextCompat.getColor(this@AiRoutingAssistantActivity, riskTextColor(action.risk)))
                            textSize = 11f
                            setTypeface(typeface, android.graphics.Typeface.BOLD)
                            setPadding(
                                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp10),
                                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4),
                                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp10),
                                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4)
                            )
                        })
                    })

                    addView(TextView(this@AiRoutingAssistantActivity).apply {
                        text = action.target
                        setTextColor(ContextCompat.getColor(this@AiRoutingAssistantActivity, R.color.flow_text_primary))
                        textSize = 13f
                        setPadding(0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp8), 0, 0)
                    })

                    addView(TextView(this@AiRoutingAssistantActivity).apply {
                        text = getString(
                            R.string.flow_ai_action_meta,
                            ((action.confidence * 100).toInt()).coerceIn(0, 100),
                            action.reason.orEmpty().ifBlank { getString(R.string.flow_value_empty) }
                        )
                        setTextColor(ContextCompat.getColor(this@AiRoutingAssistantActivity, R.color.flow_text_secondary))
                        textSize = 12f
                        setPadding(0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4), 0, 0)
                    })
                })
            })
        }
    }

    private fun toggleDetails() {
        detailsVisible = !detailsVisible
        binding.tvRawDetails.text = rawDetails
        binding.tvRawDetails.isVisible = detailsVisible && rawDetails.isNotBlank()
        binding.btnToggleDetails.text = if (detailsVisible) {
            getString(R.string.flow_ai_hide_details)
        } else {
            getString(R.string.flow_ai_show_details)
        }
    }

    private fun autonomyText(value: FlowAiAutonomy): String {
        return when (value) {
            FlowAiAutonomy.PREVIEW -> getString(R.string.flow_ai_autonomy_preview)
            FlowAiAutonomy.SAFE_AUTO -> getString(R.string.flow_ai_autonomy_safe_auto)
            FlowAiAutonomy.FULL_AUTO -> getString(R.string.flow_ai_autonomy_full_auto)
        }
    }

    private fun toolModeText(value: FlowAiToolMode): String {
        return when (value) {
            FlowAiToolMode.AUTO -> getString(R.string.flow_ai_tool_mode_auto)
            FlowAiToolMode.FUNCTION_CALL -> getString(R.string.flow_ai_tool_mode_function_call)
            FlowAiToolMode.JSON_ONLY -> getString(R.string.flow_ai_tool_mode_json_only)
        }
    }

    private fun outboundText(value: String): String {
        return when (value) {
            "proxy" -> getString(R.string.flow_ai_outbound_proxy)
            "direct" -> getString(R.string.flow_ai_outbound_direct)
            "block", "blocked" -> getString(R.string.flow_ai_outbound_block)
            else -> value
        }
    }

    private fun riskText(value: String): String {
        return when (value.lowercase()) {
            "low" -> getString(R.string.flow_ai_risk_low)
            "high" -> getString(R.string.flow_ai_risk_high)
            else -> getString(R.string.flow_ai_risk_medium)
        }
    }

    private fun riskBackground(value: String): Int {
        return when (value.lowercase()) {
            "low" -> R.drawable.flow_glass_chip_success
            "high" -> R.drawable.flow_chip_warning
            else -> R.drawable.flow_chip_neutral
        }
    }

    private fun riskTint(value: String): Int {
        return when (value.lowercase()) {
            "low" -> R.color.flow_success_soft
            "high" -> R.color.flow_warning_soft
            else -> R.color.flow_card_alt
        }
    }

    private fun riskTextColor(value: String): Int {
        return when (value.lowercase()) {
            "low" -> R.color.flow_success
            "high" -> R.color.flow_warning
            else -> R.color.flow_text_secondary
        }
    }
}
