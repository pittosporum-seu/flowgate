package com.v2ray.ang.ui

import android.text.format.DateUtils
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.recyclerview.widget.RecyclerView
import com.v2ray.ang.R
import com.v2ray.ang.databinding.ItemFlowNodePickerBinding
import com.v2ray.ang.dto.entities.ProfileItem
import com.v2ray.ang.dto.entities.ServersCache
import com.v2ray.ang.extension.nullIfBlank
import com.v2ray.ang.handler.AngConfigManager
import com.v2ray.ang.handler.MmkvManager

class FlowNodePickerAdapter(
    private val onSelect: (ServersCache) -> Unit,
) : RecyclerView.Adapter<FlowNodePickerAdapter.NodeViewHolder>() {
    private var allData: List<ServersCache> = emptyList()
    private var data: List<ServersCache> = emptyList()
    private var selectedGuid: String? = null
    private var query: String = ""

    fun submit(nodes: List<ServersCache>, selected: String?) {
        allData = nodes
        selectedGuid = selected
        applyFilter(query)
    }

    fun applyFilter(value: String) {
        query = value.trim()
        data = if (query.isBlank()) {
            allData
        } else {
            allData.filter { item ->
                val profile = item.profile
                listOf(
                    profile.remarks,
                    profile.server.orEmpty(),
                    profile.description.orEmpty(),
                    profile.configType.name,
                    subscriptionName(profile)
                ).any { it.contains(query, ignoreCase = true) }
            }
        }
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): NodeViewHolder {
        return NodeViewHolder(
            ItemFlowNodePickerBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        )
    }

    override fun onBindViewHolder(holder: NodeViewHolder, position: Int) {
        holder.bind(data[position])
    }

    override fun getItemCount(): Int = data.size

    fun visibleNodes(): List<ServersCache> = data

    private fun subscriptionName(profile: ProfileItem): String {
        return MmkvManager.decodeSubscription(profile.subscriptionId)?.remarks?.firstOrNull()?.toString().orEmpty()
    }

    inner class NodeViewHolder(private val binding: ItemFlowNodePickerBinding) : RecyclerView.ViewHolder(binding.root) {
        fun bind(item: ServersCache) {
            val context = binding.root.context
            val profile = item.profile
            val aff = MmkvManager.decodeServerAffiliationInfo(item.guid)
            val isSelected = item.guid == selectedGuid

            binding.tvName.text = profile.remarks
            binding.tvDetail.text = listOf(
                profile.configType.name,
                profile.description.nullIfBlank() ?: AngConfigManager.generateDescription(profile),
                subscriptionName(profile)
            ).filter { it.isNotBlank() }.joinToString(" / ")
            binding.tvCurrent.isVisible = isSelected

            val delay = aff?.getTestDelayString().orEmpty().ifBlank { "-- ms" }
            binding.tvDelay.text = delay
            binding.tvDelay.setTextColor(
                ContextCompat.getColor(
                    context,
                    if ((aff?.testDelayMillis ?: 0L) < 0L) R.color.flow_danger else R.color.flow_success
                )
            )

            val speed = aff?.getDownloadSpeedString().orEmpty()
            binding.tvSpeed.text = if (speed.isBlank()) {
                context.getString(R.string.flow_node_no_speed)
            } else {
                context.getString(R.string.flow_node_speed_meta, speed)
            }

            binding.tvState.text = when {
                aff?.benchmarkState.isNullOrBlank() && (aff?.downloadTestAt ?: 0L) <= 0L -> ""
                (aff?.downloadTestAt ?: 0L) > 0L -> DateUtils.getRelativeTimeSpanString(
                    aff?.downloadTestAt ?: 0L,
                    System.currentTimeMillis(),
                    DateUtils.MINUTE_IN_MILLIS
                )
                else -> aff?.benchmarkState.orEmpty()
            }

            binding.card.strokeColor = ContextCompat.getColor(
                context,
                if (isSelected) R.color.flow_accent else R.color.flow_line
            )
            binding.card.strokeWidth = if (isSelected) 2 else 1
            binding.root.setOnClickListener { onSelect(item) }
            binding.card.setOnClickListener { onSelect(item) }
        }
    }
}
