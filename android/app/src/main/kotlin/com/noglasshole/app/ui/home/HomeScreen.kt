package com.noglasshole.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.rememberMultiplePermissionsState
import com.noglasshole.app.data.MediaItem
import android.os.Build

@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun HomeScreen(
    onNavigateToPreview: (Long) -> Unit,
    onNavigateToSettings: () -> Unit,
    viewModel: HomeViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        listOf(
            android.Manifest.permission.READ_MEDIA_IMAGES,
            android.Manifest.permission.READ_MEDIA_VIDEO
        )
    } else {
        listOf(android.Manifest.permission.READ_EXTERNAL_STORAGE)
    }
    val permissionState = rememberMultiplePermissionsState(permissions) { granted ->
        if (granted.values.all { it }) viewModel.loadMedia()
    }

    LaunchedEffect(permissionState.allPermissionsGranted) {
        if (permissionState.allPermissionsGranted) {
            viewModel.loadMedia()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("NoGlasshole", fontWeight = FontWeight.Bold)
                        Text(
                            "Don't be a glasshole.",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onNavigateToSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                !permissionState.allPermissionsGranted -> {
                    PermissionRequest(
                        isPermanentlyDenied = permissionState.permissions.any {
                            !it.status.isGranted && !it.status.shouldShowRationale
                        },
                        onRequest = { permissionState.launchMultiplePermissionRequest() }
                    )
                }

                uiState.isLoading -> {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center),
                        color = MaterialTheme.colorScheme.primary
                    )
                }

                uiState.error != null -> {
                    Text(
                        text = "Error: ${uiState.error}",
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(24.dp)
                    )
                }

                else -> {
                    MediaContent(
                        smartGlassesItems = uiState.smartGlassesItems,
                        allPhotos = uiState.allPhotos,
                        onItemClick = { onNavigateToPreview(it.id) }
                    )
                }
            }
        }
    }
}

@Composable
private fun MediaContent(
    smartGlassesItems: List<MediaItem>,
    allPhotos: List<MediaItem>,
    onItemClick: (MediaItem) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(3),
        contentPadding = PaddingValues(4.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        if (smartGlassesItems.isNotEmpty()) {
            item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(3) }) {
                SectionHeader(
                    title = "Smart Glasses",
                    count = smartGlassesItems.size
                )
            }
            items(smartGlassesItems, key = { it.id }) { item ->
                MediaThumbnail(item = item, onClick = { onItemClick(item) })
            }
        }

        if (allPhotos.isNotEmpty()) {
            item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(3) }) {
                SectionHeader(
                    title = "All Photos",
                    count = allPhotos.size
                )
            }
            items(allPhotos, key = { it.id }) { item ->
                MediaThumbnail(item = item, onClick = { onItemClick(item) })
            }
        }

        if (smartGlassesItems.isEmpty() && allPhotos.isEmpty()) {
            item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(3) }) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(300.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "No photos found",
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String, count: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold
        )
        Surface(
            shape = RoundedCornerShape(50),
            color = MaterialTheme.colorScheme.surfaceVariant
        ) {
            Text(
                text = count.toString(),
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
            )
        }
    }
}

@Composable
private fun MediaThumbnail(item: MediaItem, onClick: () -> Unit) {
    val context = LocalContext.current
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(2.dp))
            .clickable(onClick = onClick)
            .background(MaterialTheme.colorScheme.surfaceVariant)
    ) {
        AsyncImage(
            model = ImageRequest.Builder(context)
                .data(item.uri)
                .crossfade(true)
                .size(300, 300)
                .build(),
            contentDescription = item.displayName,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )

        if (item.isSmartGlasses) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(4.dp)
                    .background(
                        MaterialTheme.colorScheme.primary,
                        RoundedCornerShape(4.dp)
                    )
                    .padding(horizontal = 4.dp, vertical = 2.dp)
            ) {
                Text(
                    text = "Glasses",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onPrimary
                )
            }
        }
    }
}

@Composable
private fun PermissionRequest(
    isPermanentlyDenied: Boolean,
    onRequest: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = if (isPermanentlyDenied) "Access Denied" else "Photo Access Required",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(16.dp))
        Text(
            text = if (isPermanentlyDenied)
                "Please enable photo access in Settings to use NoGlasshole."
            else
                "NoGlasshole needs access to your photos to detect and blur faces. All processing happens on-device.",
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = onRequest,
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            ),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                if (isPermanentlyDenied) "Open Settings" else "Grant Access",
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
