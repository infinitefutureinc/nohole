package com.noglasshole.app.ui.preview

import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.content.Intent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.noglasshole.app.data.MediaItem
import com.noglasshole.app.service.DetectedFace
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

@Composable
fun MediaPreviewScreen(
    mediaId: Long,
    onNavigateUp: () -> Unit,
    viewModel: MediaPreviewViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    // The preview screen needs the MediaItem. Since we use type-safe nav with the mediaId,
    // we load via the ViewModel which uses the Application's ContentResolver.
    LaunchedEffect(mediaId) {
        if (uiState.item == null || uiState.item?.id != mediaId) {
            viewModel.loadMediaById(mediaId)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (uiState.item?.isSmartGlasses == true) "Smart Glasses Photo" else "Photo",
                        fontWeight = FontWeight.SemiBold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateUp) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (uiState.processedBitmap != null) {
                        ShareButton(bitmap = uiState.processedBitmap!!)
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
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Image preview
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center
            ) {
                when {
                    uiState.isProcessing -> {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(300.dp)
                                .background(MaterialTheme.colorScheme.surfaceVariant),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                                Spacer(Modifier.height(12.dp))
                                Text(
                                    "Detecting faces…",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                )
                            }
                        }
                    }
                    uiState.processedBitmap != null -> {
                        Image(
                            bitmap = uiState.processedBitmap!!.asImageBitmap(),
                            contentDescription = "Processed photo",
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                    else -> {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(300.dp)
                                .background(MaterialTheme.colorScheme.surfaceVariant),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                if (uiState.error != null) "Failed to load" else "Loading…",
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                        }
                    }
                }
            }

            // Face detection summary
            if (uiState.detectedFaces.isNotEmpty()) {
                Text(
                    text = "${uiState.detectedFaces.count { it.isBlurred }} of ${uiState.detectedFaces.size} face(s) blurred",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            } else if (!uiState.isProcessing && uiState.processedBitmap != null) {
                Text(
                    "No faces detected",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            // Selective blur controls
            if (uiState.detectedFaces.isNotEmpty() && uiState.settings.selectiveBlurEnabled) {
                SelectiveFaceControls(
                    faces = uiState.detectedFaces,
                    onToggle = { viewModel.toggleFaceBlur(it) }
                )
            }

            // Save button
            if (uiState.processedBitmap != null) {
                Button(
                    onClick = { viewModel.saveImage() },
                    enabled = !uiState.isSaving,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    Text(
                        if (uiState.isSaving) "Saving…" else "Save to Photos",
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            if (uiState.savedSuccessfully) {
                Text(
                    "✓ Saved to Photos",
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            if (uiState.error != null) {
                Text(
                    uiState.error!!,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SelectiveFaceControls(
    faces: List<DetectedFace>,
    onToggle: (Int) -> Unit
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            "Tap to toggle blur on individual faces",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            faces.forEachIndexed { index, face ->
                Box(
                    modifier = Modifier
                        .size(60.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .then(
                            if (!face.isBlurred)
                                Modifier.border(2.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(8.dp))
                            else Modifier
                        )
                        .clickable { onToggle(face.id) },
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(if (face.isBlurred) "🫥" else "😊")
                        Text(
                            "Face ${index + 1}",
                            style = MaterialTheme.typography.labelSmall,
                            color = if (!face.isBlurred) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ShareButton(bitmap: Bitmap) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    IconButton(onClick = {
        scope.launch(Dispatchers.IO) {
            try {
                val file = File(context.cacheDir, "noglasshole_${System.currentTimeMillis()}.jpg")
                file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it) }
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/jpeg"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                withContext(Dispatchers.Main) {
                    context.startActivity(Intent.createChooser(intent, "Share via"))
                }
            } catch (_: Exception) {}
        }
    }) {
        Icon(Icons.Default.Share, contentDescription = "Share")
    }
}
