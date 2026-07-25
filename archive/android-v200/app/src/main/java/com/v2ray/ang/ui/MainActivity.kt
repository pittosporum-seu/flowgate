package com.v2ray.ang.ui

import android.content.Intent
import android.content.res.ColorStateList
import android.net.Uri
import android.net.VpnService
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.Menu
import android.view.MenuItem
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.widget.SearchView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.isVisible
import androidx.core.view.updatePadding
import androidx.core.widget.doAfterTextChanged
import androidx.lifecycle.Observer
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.tabs.TabLayoutMediator
import com.v2ray.ang.AppConfig
import com.v2ray.ang.R
import com.v2ray.ang.core.CoreServiceManager
import com.v2ray.ang.databinding.ActivityMainBinding
import com.v2ray.ang.databinding.DialogFlowNodePickerBinding
import com.v2ray.ang.enums.EConfigType
import com.v2ray.ang.enums.FlowRoutePack
import com.v2ray.ang.enums.FlowSubscriptionUpdateMode
import com.v2ray.ang.enums.ConnectionState
import com.v2ray.ang.enums.PermissionType
import com.v2ray.ang.enums.RouteMode
import com.v2ray.ang.extension.toast
import com.v2ray.ang.extension.toastError
import com.v2ray.ang.handler.AngConfigManager
import com.v2ray.ang.handler.FlowAdaptiveServiceManager
import com.v2ray.ang.handler.FlowGateModeManager
import com.v2ray.ang.handler.MmkvManager
import com.v2ray.ang.handler.SettingsChangeManager
import com.v2ray.ang.handler.SettingsManager
import com.v2ray.ang.handler.SubscriptionUpdater
import com.v2ray.ang.util.LogUtil
import com.v2ray.ang.util.Utils
import com.v2ray.ang.viewmodel.MainViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : HelperBaseActivity() {
    private val binding by lazy {
        ActivityMainBinding.inflate(layoutInflater)
    }

    val mainViewModel: MainViewModel by viewModels()
    private lateinit var groupPagerAdapter: GroupPagerAdapter
    private var tabMediator: TabLayoutMediator? = null
    private var flowDashboardJob: Job? = null
    private var pendingRestartDismissed = false

    private val requestVpnPermission = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        if (it.resultCode == RESULT_OK) {
            startV2Ray()
        }
    }
    private val requestActivityLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        if (SettingsChangeManager.consumeRestartService()) {
            if (mainViewModel.isRunning.value == true) {
                AlertDialog.Builder(this)
                    .setTitle(R.string.flow_pending_restart)
                    .setMessage(R.string.flow_pending_restart_detail)
                    .setNegativeButton(R.string.flow_pending_later) { _, _ ->
                        SettingsChangeManager.makeRestartService()
                        pendingRestartDismissed = false
                        updatePendingRestartBar()
                    }
                    .setPositiveButton(R.string.flow_pending_restart_now) { _, _ -> restartV2Ray() }
                    .show()
            } else {
                toast(R.string.flow_pending_applies_next_connect)
            }
        }
        if (SettingsChangeManager.consumeSetupGroupTab()) {
            setupGroupTab()
        }
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(binding.root)
        setupEdgeToEdge()
        setupToolbar(binding.toolbar, false, getString(R.string.flow_nav_console))

        // setup viewpager and tablayout
        groupPagerAdapter = GroupPagerAdapter(this, emptyList())
        binding.viewPager.adapter = groupPagerAdapter
        binding.viewPager.isUserInputEnabled = true

        setupBottomNavigation()
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (binding.bottomNav.selectedItemId != R.id.nav_console) {
                    binding.bottomNav.selectedItemId = R.id.nav_console
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                    isEnabled = true
                }
            }
        })

        binding.btnConnect.setOnClickListener { handleConnectAction() }
        binding.layoutTest.setOnClickListener { handleLayoutTestClick() }
        binding.btnPendingLater.setOnClickListener {
            pendingRestartDismissed = true
            updatePendingRestartBar()
        }
        binding.btnPendingRestart.setOnClickListener {
            SettingsChangeManager.clearRestartService()
            pendingRestartDismissed = false
            updatePendingRestartBar()
            if (mainViewModel.isRunning.value == true) {
                restartV2Ray()
            } else {
                toast(R.string.flow_pending_applies_next_connect)
            }
        }
        setupFlowDashboard()

        setupGroupTab()
        setupViewModel()
        SubscriptionUpdater.sync()
        mainViewModel.reloadServerList()

        checkAndRequestPermission(PermissionType.POST_NOTIFICATIONS) {
        }
    }

    private fun setupEdgeToEdge() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        ViewCompat.setOnApplyWindowInsetsListener(binding.rootContent) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.updatePadding(left = bars.left, right = bars.right)
            insets
        }
        ViewCompat.setOnApplyWindowInsetsListener(binding.appBarLayout) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.updatePadding(top = bars.top)
            insets
        }
        ViewCompat.setOnApplyWindowInsetsListener(binding.layoutTest) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.updatePadding(bottom = bars.bottom)
            insets
        }
        ViewCompat.setOnApplyWindowInsetsListener(binding.bottomNav) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.updatePadding(bottom = bars.bottom)
            insets
        }
    }

    private fun setupBottomNavigation() {
        binding.bottomNav.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_console -> {
                    showMainPage(R.id.nav_console)
                    true
                }
                R.id.nav_nodes -> {
                    showMainPage(R.id.nav_nodes)
                    true
                }
                R.id.nav_routing -> {
                    showMainPage(R.id.nav_routing)
                    true
                }
                R.id.nav_diagnostics -> {
                    showMainPage(R.id.nav_diagnostics)
                    true
                }
                R.id.nav_settings -> {
                    showMainPage(R.id.nav_settings)
                    true
                }
                else -> false
            }
        }
        binding.bottomNav.selectedItemId = R.id.nav_console
    }

    private fun showMainPage(itemId: Int) {
        binding.pageConsole.isVisible = itemId == R.id.nav_console
        binding.pageNodes.isVisible = itemId == R.id.nav_nodes
        binding.pageRouting.isVisible = itemId == R.id.nav_routing
        binding.pageDiagnostics.isVisible = itemId == R.id.nav_diagnostics
        binding.pageSettings.isVisible = itemId == R.id.nav_settings
        supportActionBar?.title = when (itemId) {
            R.id.nav_nodes -> getString(R.string.flow_nav_nodes)
            R.id.nav_routing -> getString(R.string.flow_nav_routing)
            R.id.nav_diagnostics -> getString(R.string.flow_nav_diagnostics)
            R.id.nav_settings -> getString(R.string.flow_nav_settings)
            else -> getString(R.string.flow_nav_console)
        }
    }

    private fun setupViewModel() {
        mainViewModel.updateTestResultAction.observe(this) { setTestState(it) }
        mainViewModel.isRunning.observe(this) { isRunning ->
            applyRunningState(false, isRunning)
        }
        mainViewModel.startListenBroadcast()
        mainViewModel.initAssets(assets)
    }

    private fun setupGroupTab() {
        val groups = mainViewModel.getSubscriptions(this)
        groupPagerAdapter.update(groups)

        tabMediator?.detach()
        tabMediator = TabLayoutMediator(binding.tabGroup, binding.viewPager) { tab, position ->
            groupPagerAdapter.groups.getOrNull(position)?.let {
                tab.text = it.remarks
                tab.tag = it.id
            }
        }.also { it.attach() }

        val targetIndex = groups.indexOfFirst { it.id == mainViewModel.subscriptionId }.takeIf { it >= 0 } ?: (groups.size - 1)
        binding.viewPager.setCurrentItem(targetIndex, false)

        binding.tabGroup.isVisible = groups.size > 1
        refreshFlowDashboard()
    }

    private fun setupFlowDashboard() {
        binding.modeOff.setOnClickListener { turnFlowGateOff() }
        binding.modeGlobal.setOnClickListener { applyFlowMode(RouteMode.GLOBAL) }
        binding.modeSmart.setOnClickListener { applyFlowMode(RouteMode.SMART) }
        binding.modeBlockCn.setOnClickListener { applyFlowMode(RouteMode.BLOCK_CN) }
        binding.modeCustom.setOnClickListener { applyFlowMode(RouteMode.CUSTOM) }

        binding.btnSelectNode.setOnClickListener { showNodePickerDialog() }
        binding.btnNodePickerTab.setOnClickListener { showNodePickerDialog() }
        binding.tvFlowNodeValue.setOnClickListener { showNodePickerDialog() }
        binding.btnUpdateSubscriptions.setOnClickListener { importConfigViaSub() }
        binding.btnRulePacks.setOnClickListener { showRulePackDialog() }
        binding.btnPerApp.setOnClickListener {
            requestActivityLauncher.launch(Intent(this, PerAppProxyActivity::class.java))
        }
        binding.btnSubscriptionMode.setOnClickListener { showSubscriptionUpdateModeDialog() }
        binding.btnRouteEditor.setOnClickListener {
            requestActivityLauncher.launch(Intent(this, RoutingSettingActivity::class.java))
        }
        binding.btnRouteSimulator.setOnClickListener { showRouteSimulatorDialog() }
        binding.btnChatgptRepair.setOnClickListener { handleChatGptRepair() }
        binding.btnAiAssistant.setOnClickListener {
            requestActivityLauncher.launch(Intent(this, AiRoutingAssistantActivity::class.java))
        }
        binding.btnLogcatTab.setOnClickListener { startActivity(Intent(this, LogcatActivity::class.java)) }
        binding.btnAiModelsTab.setOnClickListener {
            requestActivityLauncher.launch(Intent(this, AiModelLibraryActivity::class.java))
        }
        binding.btnSettingsTab.setOnClickListener {
            requestActivityLauncher.launch(Intent(this, SettingsActivity::class.java))
        }
        binding.btnBackupTab.setOnClickListener {
            requestActivityLauncher.launch(Intent(this, BackupActivity::class.java))
        }
        binding.btnServiceProbe.setOnClickListener { runAdaptiveProbe(force = true) }
        binding.btnDiagnostics.setOnClickListener { showDiagnosticsDialog() }
        binding.tvServiceDeepseek.setOnClickListener { showServiceDetailsDialog("deepseek") }
        binding.tvServiceOpenai.setOnClickListener { showServiceDetailsDialog("openai") }
        binding.tvServiceGoogle.setOnClickListener { showServiceDetailsDialog("google_play") }

        refreshFlowDashboard()
    }

    private fun turnFlowGateOff() {
        binding.modeOff.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        if (mainViewModel.isRunning.value == true) {
            FlowGateModeManager.setConnectionState(ConnectionState.DISCONNECTING)
            refreshFlowDashboard()
            CoreServiceManager.stopVService(this)
            toast(R.string.flow_mode_off_applied)
        } else {
            FlowGateModeManager.setConnectionState(ConnectionState.OFF)
            refreshFlowDashboard()
            toast(R.string.flow_status_disconnected)
        }
    }

    private fun applyFlowMode(mode: RouteMode) {
        if (mainViewModel.isRunning.value == true && mode != FlowGateModeManager.getMode()) {
            AlertDialog.Builder(this)
                .setTitle(getString(R.string.flow_mode_switch_title, getString(mode.titleRes)))
                .setMessage(getString(R.string.flow_mode_switch_message, getString(mode.titleRes)))
                .setNegativeButton(android.R.string.cancel) { _, _ -> refreshFlowDashboard() }
                .setPositiveButton(R.string.flow_mode_switch_restart) { _, _ -> applyFlowModeNow(mode) }
                .show()
            return
        }
        applyFlowModeNow(mode)
    }

    private fun applyFlowModeNow(mode: RouteMode) {
        binding.tvFlowStatus.setText(R.string.flow_status_applying)
        FlowGateModeManager.setConnectionState(ConnectionState.RECONFIGURING)
        val result = FlowGateModeManager.applyModeResult(this, mode)
        refreshFlowDashboard()

        if (!result.success) {
            toast(getString(R.string.flow_mode_apply_failed, result.message.orEmpty()))
            return
        }

        if (mode == RouteMode.CUSTOM) {
            toast(R.string.flow_mode_custom_opened)
            requestActivityLauncher.launch(Intent(this, RoutingSettingActivity::class.java))
            return
        }

        if (result.requiresRestart) {
            SettingsChangeManager.makeRestartService()
        }

        if (mainViewModel.isRunning.value == true && result.requiresRestart) {
            toast(R.string.flow_mode_applied_restart)
            restartV2Ray()
        } else {
            toast(R.string.flow_mode_applied)
        }
    }

    private fun handleChatGptRepair() {
        binding.btnChatgptRepair.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        binding.tvFlowStatus.setText(R.string.flow_status_applying)

        val result = FlowGateModeManager.applyChatGptRepair(this)
        refreshFlowDashboard()

        if (!result.success) {
            toast(getString(R.string.flow_mode_apply_failed, result.message.orEmpty()))
            return
        }

        SettingsChangeManager.makeRestartService()
        if (mainViewModel.isRunning.value == true && result.requiresRestart) {
            toast(R.string.flow_chatgpt_repair_restart)
            restartV2Ray()
        } else {
            toast(R.string.flow_chatgpt_repair_applied)
        }
    }

    private fun showRulePackDialog() {
        val options = FlowGateModeManager.getRoutePackOptions(this)
        val labels = options.map {
            val marker = if (it.active) "* " else ""
            "$marker${it.title} - ${it.ruleCount}\n${it.summary}"
        }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle(R.string.flow_rule_pack_dialog_title)
            .setItems(labels) { _, which ->
                val selected = options[which].routePack
                if (selected == FlowRoutePack.CUSTOM) {
                    FlowGateModeManager.markCustomRouting()
                    refreshFlowDashboard()
                    requestActivityLauncher.launch(Intent(this, RoutingSettingActivity::class.java))
                    return@setItems
                }

                val result = FlowGateModeManager.applyRoutePackResult(this, selected)
                refreshFlowDashboard()
                if (!result.success) {
                    toast(getString(R.string.flow_mode_apply_failed, result.message.orEmpty()))
                    return@setItems
                }

                SettingsChangeManager.makeRestartService()
                if (mainViewModel.isRunning.value == true && result.requiresRestart) {
                    toast(R.string.flow_mode_applied_restart)
                    restartV2Ray()
                } else {
                    toast(R.string.flow_rule_pack_applied)
                }
            }
            .setNeutralButton(R.string.flow_restore_rule_pack) { _, _ ->
                val result = FlowGateModeManager.restoreDefaultsForCurrentMode(this)
                refreshFlowDashboard()
                if (!result.success) {
                    toast(getString(R.string.flow_mode_apply_failed, result.message.orEmpty()))
                    return@setNeutralButton
                }
                SettingsChangeManager.makeRestartService()
                if (mainViewModel.isRunning.value == true && result.requiresRestart) {
                    restartV2Ray()
                }
            }
            .show()
    }

    private fun showModeChooserDialog() {
        val modes = RouteMode.entries.toTypedArray()
        val active = FlowGateModeManager.getMode()
        val labels = modes.map {
            val marker = if (it == active) "* " else ""
            "$marker${getString(it.titleRes)}\n${getString(it.summaryRes)}"
        }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle(R.string.flow_nav_policy)
            .setItems(labels) { _, which ->
                applyFlowMode(modes[which])
            }
            .show()
    }

    private fun showSubscriptionUpdateModeDialog() {
        val modes = arrayOf(
            FlowSubscriptionUpdateMode.AUTO,
            FlowSubscriptionUpdateMode.DIRECT,
            FlowSubscriptionUpdateMode.CURRENT_PROXY
        )
        val active = FlowGateModeManager.getSubscriptionUpdateMode()
        val labels = modes.map {
            val marker = if (it == active) "* " else ""
            "$marker${getString(it.titleRes)}\n${getString(it.summaryRes)}"
        }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle(R.string.flow_subscription_update_dialog_title)
            .setItems(labels) { _, which ->
                FlowGateModeManager.setSubscriptionUpdateMode(modes[which])
                refreshFlowDashboard()
                toast(R.string.flow_mode_applied)
            }
            .show()
    }

    private fun showNodePickerDialog() {
        if (mainViewModel.serversCache.isEmpty()) {
            mainViewModel.reloadServerList()
        }
        if (mainViewModel.serversCache.isEmpty()) {
            toast(R.string.flow_add_subscription_first)
            requestActivityLauncher.launch(Intent(this, SubSettingActivity::class.java))
            return
        }

        val sheetBinding = DialogFlowNodePickerBinding.inflate(layoutInflater)
        val dialog = BottomSheetDialog(this)
        val adapter = FlowNodePickerAdapter { node ->
            val selected = MmkvManager.getSelectServer()
            if (node.guid != selected) {
                if (mainViewModel.isRunning.value == true) {
                    AlertDialog.Builder(this)
                        .setTitle(R.string.flow_node_switch_title)
                        .setMessage(getString(R.string.flow_node_switch_message, node.profile.remarks))
                        .setNegativeButton(android.R.string.cancel, null)
                        .setPositiveButton(R.string.flow_pending_restart_now) { _, _ ->
                            selectNodeAndRefresh(node.guid)
                            restartV2Ray()
                            dialog.dismiss()
                            locateSelectedServer()
                        }
                        .show()
                    return@FlowNodePickerAdapter
                }
                selectNodeAndRefresh(node.guid)
            }
            dialog.dismiss()
            locateSelectedServer()
        }
        fun refreshAdapter() {
            val selected = MmkvManager.getSelectServer()
            val nodes = mainViewModel.serversCache.toList().sortedByDescending { it.guid == selected }
            adapter.submit(nodes, selected)
            adapter.applyFilter(sheetBinding.etSearch.text?.toString().orEmpty())
        }

        sheetBinding.recyclerNodes.layoutManager = LinearLayoutManager(this)
        sheetBinding.recyclerNodes.adapter = adapter
        sheetBinding.etSearch.doAfterTextChanged { adapter.applyFilter(it?.toString().orEmpty()) }
        sheetBinding.btnTcp.setOnClickListener {
            toast(getString(R.string.connection_test_testing_count, mainViewModel.serversCache.count()))
            mainViewModel.testAllTcping()
        }
        sheetBinding.btnReal.setOnClickListener {
            toast(getString(R.string.connection_test_testing_count, mainViewModel.serversCache.count()))
            mainViewModel.testAllRealPing()
        }
        sheetBinding.btnDownload.setOnClickListener {
            toast(R.string.flow_node_testing_download)
            mainViewModel.testDownloadSpeedForGuids(adapter.visibleNodes().map { it.guid })
        }
        sheetBinding.btnSort.setOnClickListener {
            mainViewModel.sortByBestNodeResults()
            mainViewModel.reloadServerList()
            refreshAdapter()
            toast(R.string.flow_node_sorted)
        }

        val observer = Observer<Int> { refreshAdapter() }
        mainViewModel.updateListAction.observe(this, observer)
        dialog.setOnDismissListener { mainViewModel.updateListAction.removeObserver(observer) }
        dialog.setContentView(sheetBinding.root)
        dialog.setOnShowListener {
            val bottomSheet = dialog.findViewById<android.view.View>(com.google.android.material.R.id.design_bottom_sheet)
            bottomSheet?.let {
                it.layoutParams.height = (resources.displayMetrics.heightPixels * 0.92f).toInt()
                BottomSheetBehavior.from(it).state = BottomSheetBehavior.STATE_EXPANDED
            }
        }
        refreshAdapter()
        dialog.show()
    }

    private fun selectNodeAndRefresh(guid: String) {
        MmkvManager.setSelectServer(guid)
        mainViewModel.reloadServerList()
        refreshFlowDashboard()
    }

    private fun refreshFlowDashboard() {
        val state = FlowGateModeManager.getDashboardState(this, mainViewModel.isRunning.value == true)
        val mode = state.mode
        binding.groupFlowModes.check(
            if (!state.isRunning) {
                R.id.mode_off
            } else when (mode) {
                RouteMode.GLOBAL -> R.id.mode_global
                RouteMode.SMART -> R.id.mode_smart
                RouteMode.BLOCK_CN -> R.id.mode_block_cn
                RouteMode.CUSTOM -> R.id.mode_custom
            }
        )
        binding.tvFlowModeDescription.setText(mode.summaryRes)
        binding.tvFlowRulePack.text = getString(R.string.flow_rule_pack) + ": " + FlowGateModeManager.routePackSummary(this)
        binding.tvFlowAppScope.text = getString(R.string.flow_app_scope) + ": " + state.appScope
        binding.tvFlowNodeValue.text = state.selectedProfileName
        binding.tvFlowDelayValue.text = state.delayText
        binding.tvFlowProxyTraffic.text = getString(R.string.flow_proxy_traffic) + ": " + state.proxyTrafficText
        binding.tvFlowDirectTraffic.text = getString(R.string.flow_direct_traffic) + ": " + state.directTrafficText
        binding.tvFlowSubscriptionUpdate.text = getString(R.string.flow_last_subscription_update) + ": " + state.lastSubscriptionUpdate
        binding.tvFlowSubscriptionMode.text = getString(R.string.flow_subscription_mode) + ": " + getString(state.subscriptionUpdateMode.titleRes)
        binding.tvFlowError.isVisible = state.lastError != null
        binding.tvFlowError.text = state.lastError?.let { getString(R.string.flow_recent_error) + ": " + it }.orEmpty()
        binding.tvFlowDiagnostic.isVisible = state.diagnosticStatus != null
        binding.tvFlowDiagnostic.text = state.diagnosticStatus.orEmpty()
        updateServiceAvailability(state.serviceLines)
        binding.tvFlowStatus.setText(
            when {
                state.isRunning -> R.string.flow_status_connected
                state.connectionState == ConnectionState.RECONFIGURING -> R.string.flow_status_reconfiguring
                state.connectionState == ConnectionState.REQUESTING_PERMISSION -> R.string.flow_status_requesting_permission
                state.connectionState == ConnectionState.CONNECTING || state.connectionState == ConnectionState.PREPARING -> R.string.flow_status_connecting
                state.connectionState == ConnectionState.ERROR -> R.string.flow_status_error
                state.connectionState == ConnectionState.NO_NODE -> R.string.flow_status_no_node
                else -> R.string.flow_status_disconnected
            }
        )
        binding.tvFlowStatus.setBackgroundResource(
            if (state.isRunning) R.drawable.flow_chip_accent else R.drawable.flow_chip_neutral
        )
        updateConnectButton(isLoading = false, isRunning = state.isRunning)
        updatePendingRestartBar()
    }

    private fun updatePendingRestartBar() {
        binding.pendingRestartBar.isVisible =
            SettingsChangeManager.hasPendingRestart() && !pendingRestartDismissed
    }

    private fun updateServiceAvailability(lines: List<FlowAdaptiveServiceManager.DashboardLine>) {
        fun labelFor(serviceId: String): String {
            val line = lines.firstOrNull { it.serviceId == serviceId }
            return if (line == null) {
                getString(R.string.flow_service_line_empty)
            } else {
                getString(R.string.flow_service_line_format, line.title, line.summary)
            }
        }
        binding.tvServiceDeepseek.text = labelFor("deepseek")
        binding.tvServiceOpenai.text = labelFor("openai")
        binding.tvServiceGoogle.text = labelFor("google_play")
    }

    private fun runAdaptiveProbe(force: Boolean) {
        binding.btnServiceProbe.isEnabled = false
        binding.tvFlowDiagnostic.isVisible = true
        binding.tvFlowDiagnostic.setText(R.string.flow_service_probe_running)
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                FlowAdaptiveServiceManager.probePrimary(this@MainActivity, force)
            }
            val applyResult = FlowGateModeManager.applyModeResult(this@MainActivity, FlowGateModeManager.getMode())
            if (mainViewModel.isRunning.value == true && applyResult.requiresRestart) {
                SettingsChangeManager.makeRestartService()
                restartV2Ray()
            }
            binding.btnServiceProbe.isEnabled = true
            refreshFlowDashboard()
            toast(result.message)
        }
    }

    private fun showDiagnosticsDialog() {
        val state = FlowGateModeManager.getDashboardState(this, mainViewModel.isRunning.value == true)
        val report = FlowAdaptiveServiceManager.diagnosticReport(
            context = this,
            isRunning = state.isRunning,
            routeModeTitle = getString(state.mode.titleRes),
            nodeName = state.selectedProfileName
        )
        AlertDialog.Builder(this)
            .setTitle(R.string.flow_diagnostics_title)
            .setMessage(report)
            .setPositiveButton(R.string.flow_diagnostic_copy_report) { _, _ ->
                Utils.setClipboard(this, report)
                toast(R.string.toast_success)
            }
            .setNeutralButton(R.string.flow_service_probe_again) { _, _ -> runAdaptiveProbe(force = true) }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun showServiceDetailsDialog(serviceId: String) {
        val target = FlowAdaptiveServiceManager.getTargets().firstOrNull { it.id == serviceId } ?: return
        val decision = FlowAdaptiveServiceManager.getDecision(serviceId)
        val direct = decision?.directResult
        val proxy = decision?.proxyResult
        val message = buildString {
            appendLine(getString(R.string.flow_service_current_route))
            appendLine(decision?.action?.name ?: getString(R.string.flow_service_not_tested))
            appendLine()
            appendLine(getString(R.string.flow_service_direct_test))
            appendLine(probeLine(direct))
            appendLine()
            appendLine(getString(R.string.flow_service_proxy_test))
            appendLine(probeLine(proxy))
            appendLine()
            appendLine(getString(R.string.flow_service_decision_reason))
            appendLine(decision?.reason?.name ?: getString(R.string.flow_service_not_tested))
        }
        AlertDialog.Builder(this)
            .setTitle(target.title)
            .setMessage(message)
            .setPositiveButton(R.string.flow_service_force_direct) { _, _ ->
                FlowAdaptiveServiceManager.forceServiceAction(serviceId, com.v2ray.ang.routing.RouteAction.DIRECT)
                FlowGateModeManager.applyModeResult(this, FlowGateModeManager.getMode())
                refreshFlowDashboard()
                if (mainViewModel.isRunning.value == true) restartV2Ray()
            }
            .setNeutralButton(R.string.flow_service_force_proxy) { _, _ ->
                FlowAdaptiveServiceManager.forceServiceAction(serviceId, com.v2ray.ang.routing.RouteAction.PROXY)
                FlowGateModeManager.applyModeResult(this, FlowGateModeManager.getMode())
                refreshFlowDashboard()
                if (mainViewModel.isRunning.value == true) restartV2Ray()
            }
            .setNegativeButton(R.string.flow_service_restore_auto) { _, _ ->
                FlowAdaptiveServiceManager.clearForcedPolicy(serviceId)
                runAdaptiveProbe(force = true)
            }
            .show()
    }

    private fun probeLine(result: com.v2ray.ang.routing.ServiceProbeResult?): String {
        if (result == null) return getString(R.string.flow_service_not_tested)
        val status = if (result.success) getString(R.string.flow_probe_success) else getString(R.string.flow_probe_failed)
        val latency = result.latencyMs?.let { getString(R.string.flow_delay_ms, it) } ?: getString(R.string.flow_value_empty)
        val error = result.errorMessage?.takeIf { it.isNotBlank() }?.let { " · $it" }.orEmpty()
        return "$status · $latency$error"
    }

    private fun showRouteSimulatorDialog() {
        val mode = FlowGateModeManager.getMode()
        val services = FlowAdaptiveServiceManager.dashboardLines(this)
            .joinToString("\n") { "- ${it.title}: ${it.summary}" }
            .ifBlank { getString(R.string.flow_service_not_tested) }
        val message = buildString {
            appendLine(getString(R.string.flow_route_simulator_summary))
            appendLine()
            appendLine("${getString(R.string.flow_current_mode)}: ${getString(mode.titleRes)}")
            appendLine("${getString(R.string.flow_app_scope)}: ${FlowGateModeManager.appScopeSummary(this@MainActivity)}")
            appendLine("${getString(R.string.flow_rule_pack)}: ${FlowGateModeManager.routePackSummary(this@MainActivity)}")
            appendLine()
            appendLine(getString(R.string.flow_service_availability))
            appendLine(services)
        }
        AlertDialog.Builder(this)
            .setTitle(R.string.flow_route_simulator)
            .setMessage(message)
            .setPositiveButton(R.string.flow_service_probe_again) { _, _ -> runAdaptiveProbe(force = true) }
            .setNeutralButton(R.string.flow_route_editor) { _, _ ->
                requestActivityLauncher.launch(Intent(this, RoutingSettingActivity::class.java))
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun handleConnectAction() {
        binding.btnConnect.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
        if (mainViewModel.isRunning.value != true &&
            mainViewModel.serversCache.isEmpty() &&
            MmkvManager.getSelectServer().isNullOrEmpty()
        ) {
            toast(R.string.flow_add_subscription_first)
            requestActivityLauncher.launch(Intent(this, SubSettingActivity::class.java))
            return
        }

        applyRunningState(isLoading = true, isRunning = false)

        if (mainViewModel.isRunning.value == true) {
            FlowGateModeManager.setConnectionState(ConnectionState.DISCONNECTING)
            CoreServiceManager.stopVService(this)
        } else if (SettingsManager.isVpnMode()) {
            FlowGateModeManager.setConnectionState(ConnectionState.PREPARING)
            val intent = VpnService.prepare(this)
            if (intent == null) {
                startV2Ray()
            } else {
                FlowGateModeManager.setConnectionState(ConnectionState.REQUESTING_PERMISSION)
                refreshFlowDashboard()
                requestVpnPermission.launch(intent)
            }
        } else {
            startV2Ray()
        }
    }

    private fun handleLayoutTestClick() {
        if (mainViewModel.isRunning.value == true) {
            setTestState(getString(R.string.connection_test_testing))
            mainViewModel.testCurrentServerRealPing()
        } else {
            // service not running: keep existing no-op (could show a message if desired)
        }
    }

    private fun startV2Ray() {
        if (MmkvManager.getSelectServer().isNullOrEmpty()) {
            toast(R.string.title_file_chooser)
            return
        }
        FlowGateModeManager.setConnectionState(ConnectionState.CONNECTING)
        if (FlowGateModeManager.getMode() == RouteMode.SMART) {
            lifecycleScope.launch {
                withContext(Dispatchers.IO) {
                    FlowAdaptiveServiceManager.probePrimary(this@MainActivity, force = false)
                    FlowGateModeManager.applyModeResult(this@MainActivity, FlowGateModeManager.getMode())
                }
                CoreServiceManager.startVService(this@MainActivity)
            }
            return
        }
        CoreServiceManager.startVService(this)
    }

    fun restartV2Ray() {
        if (mainViewModel.isRunning.value == true) {
            FlowGateModeManager.setConnectionState(ConnectionState.RECONFIGURING)
            CoreServiceManager.stopVService(this)
        }
        lifecycleScope.launch {
            delay(500)
            startV2Ray()
        }
    }

    private fun setTestState(content: String?) {
        binding.tvTestState.text = content
    }

    private fun applyRunningState(isLoading: Boolean, isRunning: Boolean) {
        if (isLoading) {
            updateConnectButton(isLoading = true, isRunning = isRunning)
            return
        }

        if (isRunning) {
            FlowGateModeManager.setConnectionState(ConnectionState.CONNECTED)
            setTestState(getString(R.string.connection_connected))
            binding.layoutTest.isFocusable = true
        } else {
            FlowGateModeManager.setConnectionState(ConnectionState.OFF)
            setTestState(getString(R.string.connection_not_connected))
            binding.layoutTest.isFocusable = false
        }
        updateConnectButton(isLoading = false, isRunning = isRunning)
        refreshFlowDashboard()
    }

    private fun updateConnectButton(isLoading: Boolean, isRunning: Boolean) {
        val hasServer = mainViewModel.serversCache.isNotEmpty() || !MmkvManager.getSelectServer().isNullOrEmpty()
        val (textRes, iconRes, colorRes) = when {
            isLoading -> Triple(R.string.flow_status_applying, R.drawable.ic_fab_check, R.color.flow_accent)
            !hasServer -> Triple(R.string.flow_add_subscription, R.drawable.ic_subscriptions_24dp, R.color.md_theme_secondary)
            isRunning -> Triple(R.string.flow_disconnect, R.drawable.ic_stop_24dp, R.color.flow_accent)
            else -> Triple(R.string.flow_connect, R.drawable.ic_play_24dp, R.color.md_theme_primary)
        }
        binding.btnConnect.isEnabled = !isLoading
        binding.btnConnect.setText(textRes)
        binding.btnConnect.setIconResource(iconRes)
        binding.btnConnect.backgroundTintList = ColorStateList.valueOf(ContextCompat.getColor(this, colorRes))
        binding.btnConnect.contentDescription = getString(textRes)
    }

    override fun onResume() {
        super.onResume()
        refreshFlowDashboard()
        startFlowDashboardTicker()
    }

    override fun onPause() {
        flowDashboardJob?.cancel()
        flowDashboardJob = null
        super.onPause()
    }

    private fun startFlowDashboardTicker() {
        flowDashboardJob?.cancel()
        flowDashboardJob = lifecycleScope.launch {
            while (isActive) {
                refreshFlowDashboard()
                delay(2000L)
            }
        }
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.menu_main, menu)

        val searchItem = menu.findItem(R.id.search_view)
        if (searchItem != null) {
            val searchView = searchItem.actionView as SearchView
            searchView.setOnQueryTextListener(object : SearchView.OnQueryTextListener {
                override fun onQueryTextSubmit(query: String?): Boolean = false

                override fun onQueryTextChange(newText: String?): Boolean {
                    mainViewModel.filterConfig(newText.orEmpty())
                    return false
                }
            })

            searchView.setOnCloseListener {
                mainViewModel.filterConfig("")
                false
            }
        }
        return super.onCreateOptionsMenu(menu)
    }

    override fun onOptionsItemSelected(item: MenuItem) = when (item.itemId) {
        R.id.import_qrcode -> {
            importQRcode()
            true
        }

        R.id.import_clipboard -> {
            importClipboard()
            true
        }

        R.id.import_local -> {
            importConfigLocal()
            true
        }

        R.id.import_manually_policy_group -> {
            importManually(EConfigType.POLICYGROUP.value)
            true
        }

        R.id.import_manually_proxy_chain -> {
            importManually(EConfigType.PROXYCHAIN.value)
            true
        }

        R.id.import_manually_vmess -> {
            importManually(EConfigType.VMESS.value)
            true
        }

        R.id.import_manually_vless -> {
            importManually(EConfigType.VLESS.value)
            true
        }

        R.id.import_manually_ss -> {
            importManually(EConfigType.SHADOWSOCKS.value)
            true
        }

        R.id.import_manually_socks -> {
            importManually(EConfigType.SOCKS.value)
            true
        }

        R.id.import_manually_http -> {
            importManually(EConfigType.HTTP.value)
            true
        }

        R.id.import_manually_trojan -> {
            importManually(EConfigType.TROJAN.value)
            true
        }

        R.id.import_manually_wireguard -> {
            importManually(EConfigType.WIREGUARD.value)
            true
        }

        R.id.import_manually_hysteria2 -> {
            importManually(EConfigType.HYSTERIA2.value)
            true
        }

        R.id.export_all -> {
            exportAll()
            true
        }

        R.id.ping_all -> {
            toast(getString(R.string.connection_test_testing_count, mainViewModel.serversCache.count()))
            mainViewModel.testAllTcping()
            true
        }

        R.id.real_ping_all -> {
            toast(getString(R.string.connection_test_testing_count, mainViewModel.serversCache.count()))
            mainViewModel.testAllRealPing()
            true
        }

        R.id.service_restart -> {
            restartV2Ray()
            true
        }

        R.id.del_all_config -> {
            delAllConfig()
            true
        }

        R.id.del_duplicate_config -> {
            delDuplicateConfig()
            true
        }

        R.id.del_invalid_config -> {
            delInvalidConfig()
            true
        }

        R.id.sort_by_test_results -> {
            sortByTestResults()
            true
        }

        R.id.sub_update -> {
            importConfigViaSub()
            true
        }

        R.id.locate_selected_config -> {
            locateSelectedServer()
            true
        }

        else -> super.onOptionsItemSelected(item)
    }

    private fun importManually(createConfigType: Int) {
        if (createConfigType == EConfigType.POLICYGROUP.value) {
            startActivity(
                Intent()
                    .putExtra("subscriptionId", mainViewModel.subscriptionId)
                    .setClass(this, ServerGroupActivity::class.java)
            )
        } else if (createConfigType == EConfigType.PROXYCHAIN.value) {
            startActivity(
                Intent()
                    .putExtra("subscriptionId", mainViewModel.subscriptionId)
                    .setClass(this, ServerProxyChainActivity::class.java)
            )
        } else {
            startActivity(
                Intent()
                    .putExtra("createConfigType", createConfigType)
                    .putExtra("subscriptionId", mainViewModel.subscriptionId)
                    .setClass(this, ServerActivity::class.java)
            )
        }
    }

    /**
     * import config from qrcode
     */
    private fun importQRcode(): Boolean {
        launchQRCodeScanner { scanResult ->
            if (scanResult != null) {
                importBatchConfig(scanResult)
            }
        }
        return true
    }

    /**
     * import config from clipboard
     */
    private fun importClipboard()
            : Boolean {
        try {
            val clipboard = Utils.getClipboard(this)
            importBatchConfig(clipboard)
        } catch (e: Exception) {
            LogUtil.e(AppConfig.TAG, "Failed to import config from clipboard", e)
            return false
        }
        return true
    }

    private fun importBatchConfig(server: String?) {
        showLoading()

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val (count, countSub) = AngConfigManager.importBatchConfig(server, mainViewModel.subscriptionId, true)
                delay(500L)
                withContext(Dispatchers.Main) {
                    when {
                        count > 0 -> {
                            toast(getString(R.string.title_import_config_count, count))
                            mainViewModel.reloadServerList()
                        }

                        countSub > 0 -> setupGroupTab()
                        else -> toastError(R.string.toast_failure)
                    }
                    hideLoading()
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    toastError(R.string.toast_failure)
                    hideLoading()
                }
                LogUtil.e(AppConfig.TAG, "Failed to import batch config", e)
            }
        }
    }

    /**
     * import config from local config file
     */
    private fun importConfigLocal(): Boolean {
        try {
            showFileChooser()
        } catch (e: Exception) {
            LogUtil.e(AppConfig.TAG, "Failed to import config from local file", e)
            return false
        }
        return true
    }


    /**
     * import config from sub
     */
    fun importConfigViaSub(): Boolean {
        showLoading()

        lifecycleScope.launch(Dispatchers.IO) {
            val result = mainViewModel.updateConfigViaSubAll()
            delay(500L)
            launch(Dispatchers.Main) {
                if (result.successCount + result.failureCount + result.skipCount == 0) {
                    toast(R.string.title_update_subscription_no_subscription)
                } else if (result.successCount > 0 && result.failureCount + result.skipCount == 0) {
                    toast(getString(R.string.title_update_config_count, result.configCount))
                    result.message?.takeIf { it.isNotBlank() }?.let { toast(it) }
                } else {
                    toast(
                        getString(
                            R.string.title_update_subscription_result,
                            result.configCount, result.successCount, result.failureCount, result.skipCount
                        )
                    )
                    result.message?.takeIf { it.isNotBlank() }?.let { toast(it) }
                }
                if (result.configCount > 0) {
                    mainViewModel.reloadServerList()
                }
                refreshFlowDashboard()
                hideLoading()
            }
        }
        return true
    }

    private fun exportAll() {
        showLoading()
        lifecycleScope.launch(Dispatchers.IO) {
            val ret = mainViewModel.exportAllServer()
            launch(Dispatchers.Main) {
                if (ret > 0)
                    toast(getString(R.string.title_export_config_count, ret))
                else
                    toastError(R.string.toast_failure)
                hideLoading()
            }
        }
    }

    private fun delAllConfig() {
        AlertDialog.Builder(this).setMessage(R.string.del_config_comfirm)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                showLoading()
                lifecycleScope.launch(Dispatchers.IO) {
                    val ret = mainViewModel.removeAllServer()
                    launch(Dispatchers.Main) {
                        mainViewModel.reloadServerList()
                        toast(getString(R.string.title_del_config_count, ret))
                        hideLoading()
                    }
                }
            }
            .setNegativeButton(android.R.string.cancel) { _, _ ->
                //do noting
            }
            .show()
    }

    private fun delDuplicateConfig() {
        AlertDialog.Builder(this).setMessage(R.string.del_config_comfirm)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                showLoading()
                lifecycleScope.launch(Dispatchers.IO) {
                    val ret = mainViewModel.removeDuplicateServer()
                    launch(Dispatchers.Main) {
                        mainViewModel.reloadServerList()
                        toast(getString(R.string.title_del_duplicate_config_count, ret))
                        hideLoading()
                    }
                }
            }
            .setNegativeButton(android.R.string.cancel) { _, _ ->
                //do noting
            }
            .show()
    }

    private fun delInvalidConfig() {
        AlertDialog.Builder(this).setMessage(R.string.del_invalid_config_comfirm)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                showLoading()
                lifecycleScope.launch(Dispatchers.IO) {
                    val ret = mainViewModel.removeInvalidServer()
                    launch(Dispatchers.Main) {
                        mainViewModel.reloadServerList()
                        toast(getString(R.string.title_del_config_count, ret))
                        hideLoading()
                    }
                }
            }
            .setNegativeButton(android.R.string.cancel) { _, _ ->
                //do noting
            }
            .show()
    }

    private fun sortByTestResults() {
        showLoading()
        lifecycleScope.launch(Dispatchers.IO) {
            mainViewModel.sortByTestResults()
            launch(Dispatchers.Main) {
                mainViewModel.reloadServerList()
                hideLoading()
            }
        }
    }

    /**
     * show file chooser
     */
    private fun showFileChooser() {
        launchFileChooser { uri ->
            if (uri == null) {
                return@launchFileChooser
            }

            readContentFromUri(uri)
        }
    }

    /**
     * read content from uri
     */
    private fun readContentFromUri(uri: Uri) {
        try {
            contentResolver.openInputStream(uri).use { input ->
                importBatchConfig(input?.bufferedReader()?.readText())
            }
        } catch (e: Exception) {
            LogUtil.e(AppConfig.TAG, "Failed to read content from URI", e)
        }
    }

    /**
     * Locates and scrolls to the currently selected server.
     * If the selected server is in a different group, automatically switches to that group first.
     */
    private fun locateSelectedServer() {
        val targetSubscriptionId = mainViewModel.findSubscriptionIdBySelect()
        if (targetSubscriptionId.isNullOrEmpty()) {
            toast(R.string.title_file_chooser)
            return
        }

        val targetGroupIndex = groupPagerAdapter.groups.indexOfFirst { it.id == targetSubscriptionId }
        if (targetGroupIndex < 0) {
            toast(R.string.toast_server_not_found_in_group)
            return
        }

        // Switch to target group if needed, then scroll to the server
        if (binding.viewPager.currentItem != targetGroupIndex) {
            binding.viewPager.setCurrentItem(targetGroupIndex, true)
            binding.viewPager.postDelayed({ scrollToSelectedServer(targetGroupIndex) }, 1000)
        } else {
            scrollToSelectedServer(targetGroupIndex)
        }
    }

    /**
     * Scrolls to the selected server in the specified fragment.
     * @param groupIndex The index of the group/fragment to scroll in
     */
    private fun scrollToSelectedServer(groupIndex: Int) {
        val itemId = groupPagerAdapter.getItemId(groupIndex)
        val fragment = supportFragmentManager.findFragmentByTag("f$itemId") as? GroupServerFragment

        if (fragment?.isAdded == true && fragment.view != null) {
            fragment.scrollToSelectedServer()
        } else {
            toast(R.string.toast_fragment_not_available)
        }
    }

    override fun onDestroy() {
        tabMediator?.detach()
        super.onDestroy()
    }
}
