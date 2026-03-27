package com.noglasshole.app.ui.settings

import android.app.Application
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.noglasshole.app.data.AppSettingsData
import com.noglasshole.app.data.AppSettingsRepository
import com.noglasshole.app.data.BlurStyle
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class SettingsViewModel(app: Application) : AndroidViewModel(app) {
    private val repo = AppSettingsRepository(app)
    val settings = repo.settings.stateIn(viewModelScope, SharingStarted.Eagerly, AppSettingsData())

    fun setBlurIntensity(v: Double) = viewModelScope.launch { repo.updateBlurIntensity(v) }
    fun setBlurStyle(s: BlurStyle) = viewModelScope.launch { repo.updateBlurStyle(s) }
    fun setSelectiveBlur(e: Boolean) = viewModelScope.launch { repo.updateSelectiveBlur(e) }
    fun setMaskScale(v: Double) = viewModelScope.launch { repo.updateMaskScale(v) }
}

@Composable
fun SettingsScreen(
    onNavigateUp: () -> Unit,
    viewModel: SettingsViewModel = viewModel()
) {
    val settings by viewModel.settings.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings", fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateUp) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Blur Style
            SettingsSection(title = "Blur Style") {
                BlurStyle.entries.forEach { style ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        RadioButton(
                            selected = settings.blurStyle == style,
                            onClick = { viewModel.setBlurStyle(style) }
                        )
                        Text(style.displayName)
                    }
                }
            }

            // Blur Intensity
            SettingsSection(title = "Blur Intensity") {
                Text(
                    "${settings.blurIntensity.toInt()}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
                Slider(
                    value = settings.blurIntensity.toFloat(),
                    onValueChange = { viewModel.setBlurIntensity(it.toDouble()) },
                    valueRange = 5f..100f,
                    colors = SliderDefaults.colors(thumbColor = MaterialTheme.colorScheme.primary)
                )
            }

            // Mask Scale
            SettingsSection(title = "Face Mask Size") {
                Text(
                    String.format("%.1fx", settings.maskScale),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
                Slider(
                    value = settings.maskScale.toFloat(),
                    onValueChange = { viewModel.setMaskScale(it.toDouble()) },
                    valueRange = 1.0f..2.0f,
                    colors = SliderDefaults.colors(thumbColor = MaterialTheme.colorScheme.primary)
                )
            }

            // Selective Blur
            SettingsSection(title = "Selective Blur") {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Allow un-blurring individual faces")
                        Text(
                            "Tap faces in the preview to selectively keep them visible.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                    Switch(
                        checked = settings.selectiveBlurEnabled,
                        onCheckedChange = { viewModel.setSelectiveBlur(it) },
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = MaterialTheme.colorScheme.onPrimary,
                            checkedTrackColor = MaterialTheme.colorScheme.primary
                        )
                    )
                }
            }

            // Privacy note
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("On-Device Only", fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "All face detection and blur processing happens on your device. No photos are ever uploaded or shared.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        content()
    }
}
