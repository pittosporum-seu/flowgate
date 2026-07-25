package com.v2ray.ang.ui

import android.os.Bundle
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.View
import android.widget.ArrayAdapter
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.core.view.isVisible
import androidx.core.view.setPadding
import androidx.lifecycle.lifecycleScope
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import com.v2ray.ang.R
import com.v2ray.ang.ai.FlowAiClient
import com.v2ray.ang.ai.FlowAiProfile
import com.v2ray.ang.ai.FlowAiProfileManager
import com.v2ray.ang.ai.FlowAiProtocol
import com.v2ray.ang.ai.FlowAiSecretStore
import com.v2ray.ang.ai.FlowAiTags
import com.v2ray.ang.ai.FlowAiToolMode
import com.v2ray.ang.databinding.ActivityFlowAiModelsBinding
import com.v2ray.ang.extension.toast
import kotlinx.coroutines.launch
import java.util.UUID

class AiModelLibraryActivity : BaseActivity() {
    private val binding by lazy { ActivityFlowAiModelsBinding.inflate(layoutInflater) }
    private var providerFilter: String? = null
    private var tagFilter: String? = null
    private var query: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FlowAiProfileManager.ensureDefaults()
        setContentViewWithToolbar(binding.root, showHomeAsUp = true, title = getString(R.string.flow_ai_models_title))

        binding.btnXiaomiCodingplan.setOnClickListener { openXiaomiQuickSetup() }
        binding.btnAddProfile.setOnClickListener { showProfileEditor(null) }
        binding.btnFilterProvider.setOnClickListener { showProviderFilter() }
        binding.btnFilterTag.setOnClickListener { showTagFilter() }
        binding.etSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                query = s?.toString().orEmpty()
                render()
            }
            override fun afterTextChanged(s: Editable?) = Unit
        })
        render()
    }

    private fun render() {
        val profiles = FlowAiProfileManager.getProfiles()
        val defaultId = FlowAiProfileManager.getDefaultProfile()?.id
        val fallbackId = FlowAiProfileManager.getFallbackProfile()?.id
        val defaultProfile = profiles.firstOrNull { it.id == defaultId }
        val fallbackProfile = profiles.firstOrNull { it.id == fallbackId }
        binding.tvCurrentProfile.text = getString(
            R.string.flow_ai_current_profile,
            defaultProfile?.name ?: getString(R.string.flow_value_empty),
            fallbackProfile?.name ?: getString(R.string.flow_value_empty)
        )
        binding.btnFilterProvider.text = providerFilter?.let { getString(R.string.flow_ai_filter_provider, it) }
            ?: getString(R.string.flow_ai_filter_provider_all)
        binding.btnFilterTag.text = tagFilter?.let { getString(R.string.flow_ai_filter_tag, tagLabel(it)) }
            ?: getString(R.string.flow_ai_filter_tag_all)

        binding.profileList.removeAllViews()
        var lastProvider: String? = null
        profiles
            .filter { it.matchesFilters() }
            .sortedWith(compareByDescending<FlowAiProfile> { it.id == defaultId }
                .thenByDescending { it.favorite }
                .thenBy { it.provider }
                .thenBy { it.name })
            .forEach {
                if (it.provider != lastProvider) {
                    binding.profileList.addView(sectionHeader(it.provider))
                    lastProvider = it.provider
                }
                binding.profileList.addView(profileCard(it, it.id == defaultId, it.id == fallbackId))
            }
    }

    private fun FlowAiProfile.matchesFilters(): Boolean {
        val q = query.trim().lowercase()
        return (providerFilter == null || provider == providerFilter) &&
                (tagFilter == null || tagFilter in tags) &&
                (q.isBlank() || listOf(name, provider, model, baseUrl, tags.joinToString()).any { it.lowercase().contains(q) })
    }

    private fun profileCard(profile: FlowAiProfile, isDefault: Boolean, isFallback: Boolean): View {
        val card = MaterialCardView(this).apply {
            radius = resources.getDimension(R.dimen.padding_spacing_dp8)
            strokeWidth = 1
            setCardBackgroundColor(getColor(R.color.flow_card))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.setMargins(0, 0, 0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp10))
            layoutParams = lp
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(resources.getDimensionPixelSize(R.dimen.padding_spacing_dp16))
        }
        card.addView(content)

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        content.addView(header)
        header.addView(TextView(this).apply {
            text = profile.name
            setTextColor(getColor(R.color.flow_text_primary))
            textSize = 16f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 2
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        })
        header.addView(TextView(this).apply {
            text = when {
                isDefault -> getString(R.string.flow_ai_badge_default)
                isFallback -> getString(R.string.flow_ai_badge_fallback)
                FlowAiSecretStore.hasApiKey(this@AiModelLibraryActivity, profile.id) -> getString(R.string.flow_ai_key_configured_short)
                else -> getString(R.string.flow_ai_key_missing_short)
            }
            setBackgroundResource(if (isDefault) R.drawable.flow_chip_accent else R.drawable.flow_chip_neutral)
            setPadding(
                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp10),
                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4),
                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp10),
                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4)
            )
            setTextColor(getColor(R.color.flow_text_primary))
            textSize = 11f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })

        content.addView(TextView(this).apply {
            text = "${profile.provider} / ${protocolLabel(profile.protocol)}"
            setTextColor(getColor(R.color.flow_text_secondary))
            textSize = 12f
            setPadding(0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp6), 0, 0)
        })
        content.addView(TextView(this).apply {
            text = profile.model
            setTextColor(getColor(R.color.flow_text_primary))
            textSize = 13f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4), 0, 0)
        })
        content.addView(TextView(this).apply {
            text = profile.baseUrl
            setTextColor(getColor(R.color.flow_text_secondary))
            textSize = 12f
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.MIDDLE
        })

        content.addView(TextView(this).apply {
            val status = profile.lastStatus?.takeIf { it.isNotBlank() } ?: getString(R.string.flow_value_empty)
            text = getString(R.string.flow_ai_profile_compact_meta, profile.tags.joinToString("  ") { tagLabel(it) }, status, profile.lastLatencyMs)
            setTextColor(getColor(R.color.flow_text_secondary))
            textSize = 12f
            setPadding(0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp8), 0, 0)
        })

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        content.addView(actions)
        actions.addView(compactActionButton(getString(R.string.flow_ai_use_profile)) {
            FlowAiProfileManager.setDefault(profile.id)
            render()
        })
        actions.addView(compactActionButton(getString(R.string.flow_ai_api_key)) { showKeySheet(profile) })
        actions.addView(compactActionButton(getString(R.string.flow_ai_test_profile)) { testProfile(profile) })
        actions.addView(compactActionButton(getString(R.string.flow_ai_more_profile)) { showMoreActions(profile) })
        return card
    }

    private fun sectionHeader(provider: String): TextView {
        return TextView(this).apply {
            text = provider.ifBlank { getString(R.string.flow_ai_custom_provider) }
            setTextColor(getColor(R.color.flow_text_secondary))
            textSize = 12f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(
                0,
                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp12),
                0,
                resources.getDimensionPixelSize(R.dimen.padding_spacing_dp6)
            )
        }
    }

    private fun compactActionButton(label: String, action: () -> Unit): MaterialButton {
        return MaterialButton(this).apply {
            text = label
            isAllCaps = false
            textSize = 12f
            maxLines = 1
            setOnClickListener { action.invoke() }
            val margin = resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4)
            val lp = LinearLayout.LayoutParams(0, resources.getDimensionPixelSize(R.dimen.view_height_dp36), 1f)
            lp.setMargins(margin, margin, margin, 0)
            layoutParams = lp
        }
    }

    private fun buttonColumn(actions: List<Pair<String, () -> Unit>>): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            actions.forEachIndexed { index, action ->
                addView(MaterialButton(this@AiModelLibraryActivity).apply {
                    text = action.first
                    isAllCaps = false
                    minHeight = 0
                    minimumHeight = resources.getDimensionPixelSize(R.dimen.view_height_dp36)
                    setOnClickListener { action.second.invoke() }
                    if (index > 0) {
                        val lp = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        )
                        lp.setMargins(0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4), 0, 0)
                        layoutParams = lp
                    }
                })
            }
        }
    }

    private fun showProfileEditor(source: FlowAiProfile?) {
        val dialog = BottomSheetDialog(this)
        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(resources.getDimensionPixelSize(R.dimen.padding_spacing_dp16))
        }
        form.addView(TextView(this).apply {
            text = if (source == null) getString(R.string.flow_ai_add_profile) else getString(R.string.flow_ai_configure_profile)
            setTextColor(getColor(R.color.flow_text_primary))
            textSize = 20f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        form.addView(TextView(this).apply {
            text = getString(R.string.flow_ai_configure_hint)
            setTextColor(getColor(R.color.flow_text_secondary))
            textSize = 12f
            setPadding(0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4), 0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp8))
        })
        form.addView(sectionLabel(getString(R.string.flow_ai_section_basic)))
        val name = editText(source?.name.orEmpty(), getString(R.string.flow_ai_field_name))
        val provider = editText(source?.provider.orEmpty(), getString(R.string.flow_ai_field_provider))
        val protocol = Spinner(this)
        val protocols = FlowAiProtocol.entries.map { it.value }
        protocol.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, protocols)
        protocol.setSelection(protocols.indexOf(source?.protocol ?: FlowAiProtocol.OPENAI.value).coerceAtLeast(0))
        val baseUrl = editText(source?.baseUrl.orEmpty(), getString(R.string.flow_ai_field_base_url))
        val model = editText(source?.model.orEmpty(), getString(R.string.flow_ai_field_model))
        val tags = editText(source?.tags?.joinToString(",").orEmpty(), getString(R.string.flow_ai_field_tags))
        listOf(name, provider, baseUrl, model).forEach { form.addView(it) }
        form.addView(TextView(this).apply {
            text = getString(R.string.flow_ai_field_protocol)
            setTextColor(getColor(R.color.flow_text_secondary))
        })
        form.addView(protocol)

        form.addView(sectionLabel(getString(R.string.flow_ai_section_advanced)))
        form.addView(tags)
        val temperature = editText((source?.temperature ?: 0.2).toString(), getString(R.string.flow_ai_field_temperature))
        temperature.inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
        val toolMode = Spinner(this)
        val toolModes = FlowAiToolMode.entries.map { it.value }
        toolMode.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, toolModes)
        val selectedToolMode = source?.toolMode
            ?: FlowAiProfileManager.defaultToolMode(FlowAiProtocol.fromValue(source?.protocol))
        toolMode.setSelection(toolModes.indexOf(selectedToolMode).coerceAtLeast(0))
        val apiKey = editText("", if (source != null && FlowAiSecretStore.hasApiKey(this, source.id)) getString(R.string.flow_ai_api_key_keep_hint) else getString(R.string.flow_ai_api_key_hint)).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        }
        val makePrimary = CheckBox(this).apply {
            text = getString(R.string.flow_ai_set_default)
            isChecked = source?.id == FlowAiProfileManager.getDefaultProfile()?.id || source == null
            setTextColor(getColor(R.color.flow_text_primary))
        }
        val makeFallback = CheckBox(this).apply {
            text = getString(R.string.flow_ai_set_fallback)
            isChecked = source?.id == FlowAiProfileManager.getFallbackProfile()?.id
            setTextColor(getColor(R.color.flow_text_primary))
        }

        form.addView(temperature)
        form.addView(TextView(this).apply {
            text = getString(R.string.flow_ai_field_tool_mode)
            setTextColor(getColor(R.color.flow_text_secondary))
        })
        form.addView(toolMode)
        form.addView(sectionLabel(getString(R.string.flow_ai_section_key)))
        form.addView(apiKey)
        form.addView(makePrimary)
        form.addView(makeFallback)

        form.addView(MaterialButton(this).apply {
            text = getString(R.string.flow_ai_save_profile)
            isAllCaps = false
            setOnClickListener {
                val profile = source?.copy() ?: FlowAiProfile(id = UUID.randomUUID().toString())
                profile.name = name.text.toString().ifBlank { model.text.toString() }
                profile.provider = provider.text.toString().ifBlank { getString(R.string.flow_ai_custom_provider) }
                profile.protocol = protocol.selectedItem.toString()
                profile.baseUrl = baseUrl.text.toString()
                profile.model = model.text.toString()
                profile.tags = tags.text.toString().split(",").map { it.trim() }.filter { it.isNotBlank() }
                profile.temperature = temperature.text.toString().toDoubleOrNull() ?: 0.2
                profile.toolMode = toolMode.selectedItem.toString()
                profile.builtIn = source?.builtIn == true
                FlowAiProfileManager.save(profile)
                apiKey.text.toString().takeIf { it.isNotBlank() }?.let {
                    FlowAiSecretStore.saveApiKey(this@AiModelLibraryActivity, profile.id, it)
                }
                if (makePrimary.isChecked) {
                    FlowAiProfileManager.setDefault(profile.id)
                }
                if (makeFallback.isChecked) {
                    FlowAiProfileManager.setFallback(profile.id)
                }
                dialog.dismiss()
                render()
            }
        })
        dialog.setContentView(form)
        dialog.show()
    }

    private fun showKeySheet(profile: FlowAiProfile) {
        val dialog = BottomSheetDialog(this)
        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(resources.getDimensionPixelSize(R.dimen.padding_spacing_dp16))
        }
        form.addView(TextView(this).apply {
            text = getString(R.string.flow_ai_api_key_for, profile.name)
            setTextColor(getColor(R.color.flow_text_primary))
            textSize = 18f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        val input = editText("", getString(R.string.flow_ai_api_key_hint)).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        }
        form.addView(input)
        form.addView(MaterialButton(this).apply {
            text = getString(R.string.flow_ai_save_key)
            isAllCaps = false
            setOnClickListener {
                FlowAiSecretStore.saveApiKey(this@AiModelLibraryActivity, profile.id, input.text.toString())
                dialog.dismiss()
                render()
            }
        })
        form.addView(MaterialButton(this).apply {
            text = getString(R.string.flow_ai_clear_key)
            isAllCaps = false
            setOnClickListener {
                FlowAiSecretStore.removeApiKey(this@AiModelLibraryActivity, profile.id)
                dialog.dismiss()
                render()
            }
        })
        dialog.setContentView(form)
        dialog.show()
    }

    private fun showProviderFilter() {
        val providers = listOf<String?>(null) + FlowAiProfileManager.getProfiles().map { it.provider }.distinct().sorted()
        AlertDialog.Builder(this)
            .setTitle(R.string.flow_ai_filter_provider_title)
            .setItems(providers.map { it ?: getString(R.string.flow_ai_filter_all) }.toTypedArray()) { _, which ->
                providerFilter = providers[which]
                render()
            }
            .show()
    }

    private fun showMoreActions(profile: FlowAiProfile) {
        val actions = arrayOf(
            getString(R.string.flow_ai_edit_profile),
            getString(R.string.flow_ai_set_fallback),
            getString(R.string.flow_ai_duplicate_profile),
            getString(R.string.flow_ai_delete_profile),
            getString(R.string.flow_ai_clear_key)
        )
        AlertDialog.Builder(this)
            .setTitle(profile.name)
            .setItems(actions) { _, which ->
                when (which) {
                    0 -> showProfileEditor(profile)
                    1 -> {
                        FlowAiProfileManager.setFallback(profile.id)
                        render()
                    }
                    2 -> {
                        FlowAiProfileManager.duplicate(profile)
                        render()
                    }
                    3 -> confirmDelete(profile)
                    4 -> {
                        FlowAiSecretStore.removeApiKey(this, profile.id)
                        render()
                    }
                }
            }
            .show()
    }

    private fun openXiaomiQuickSetup() {
        providerFilter = "Xiaomi CodingPlan"
        tagFilter = FlowAiTags.CODING
        if (binding.etSearch.text.isNotBlank()) {
            binding.etSearch.setText("")
        }
        val profile = FlowAiProfileManager.getProfile("xiaomi-codingplan-mimo-v2-5-pro")
        if (profile != null) {
            showProfileEditor(profile)
        }
        render()
    }

    private fun showTagFilter() {
        val tags = listOf<String?>(null, FlowAiTags.ROUTING, FlowAiTags.FAST, FlowAiTags.REASONING, FlowAiTags.CODING, FlowAiTags.LONG_CONTEXT, FlowAiTags.CUSTOM)
        AlertDialog.Builder(this)
            .setTitle(R.string.flow_ai_filter_tag_title)
            .setItems(tags.map { it?.let { tag -> tagLabel(tag) } ?: getString(R.string.flow_ai_filter_all) }.toTypedArray()) { _, which ->
                tagFilter = tags[which]
                render()
            }
            .show()
    }

    private fun confirmDelete(profile: FlowAiProfile) {
        AlertDialog.Builder(this)
            .setMessage(getString(R.string.flow_ai_delete_confirm, profile.name))
            .setPositiveButton(android.R.string.ok) { _, _ ->
                FlowAiProfileManager.delete(this, profile.id)
                render()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun testProfile(profile: FlowAiProfile) {
        showLoading()
        lifecycleScope.launch {
            val result = FlowAiClient.testProfile(this@AiModelLibraryActivity, profile)
            hideLoading()
            toast(result.message ?: if (result.success) getString(R.string.flow_ai_test_ok) else getString(R.string.flow_ai_test_failed))
            render()
        }
    }

    private fun editText(value: String, hint: String): EditText {
        return EditText(this).apply {
            setText(value)
            this.hint = hint
            setSingleLine(true)
            setTextColor(getColor(R.color.flow_text_primary))
            setHintTextColor(getColor(R.color.flow_text_secondary))
        }
    }

    private fun sectionLabel(label: String): TextView {
        return TextView(this).apply {
            text = label
            setTextColor(getColor(R.color.flow_text_secondary))
            textSize = 12f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp12), 0, resources.getDimensionPixelSize(R.dimen.padding_spacing_dp4))
        }
    }

    private fun tagLabel(tag: String): String {
        return when (tag) {
            FlowAiTags.ROUTING -> getString(R.string.flow_ai_tag_routing)
            FlowAiTags.FAST -> getString(R.string.flow_ai_tag_fast)
            FlowAiTags.REASONING -> getString(R.string.flow_ai_tag_reasoning)
            FlowAiTags.CODING -> getString(R.string.flow_ai_tag_coding)
            FlowAiTags.LONG_CONTEXT -> getString(R.string.flow_ai_tag_long_context)
            FlowAiTags.CUSTOM -> getString(R.string.flow_ai_tag_custom)
            else -> tag
        }
    }

    private fun protocolLabel(value: String): String {
        return when (FlowAiProtocol.fromValue(value)) {
            FlowAiProtocol.OPENAI -> "OpenAI-compatible"
            FlowAiProtocol.ANTHROPIC -> "Anthropic Messages"
            FlowAiProtocol.GEMINI -> "Gemini GenerateContent"
        }
    }
}
