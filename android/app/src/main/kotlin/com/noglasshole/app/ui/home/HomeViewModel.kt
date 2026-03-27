package com.noglasshole.app.ui.home

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.noglasshole.app.data.MediaItem
import com.noglasshole.app.service.MediaLibraryManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class HomeUiState(
    val isLoading: Boolean = false,
    val smartGlassesItems: List<MediaItem> = emptyList(),
    val allPhotos: List<MediaItem> = emptyList(),
    val error: String? = null
)

class HomeViewModel(app: Application) : AndroidViewModel(app) {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    /** Cache by ID for fast O(1) lookup by the preview screen. */
    private val itemCache = mutableMapOf<Long, MediaItem>()

    fun loadMedia() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val all = MediaLibraryManager.fetchMedia(getApplication())
                itemCache.clear()
                all.forEach { itemCache[it.id] = it }
                _uiState.value = HomeUiState(
                    isLoading = false,
                    smartGlassesItems = all.filter { it.isSmartGlasses && it.isPhoto },
                    allPhotos = all.filter { it.isPhoto && !it.isSmartGlasses }
                )
            } catch (e: Exception) {
                _uiState.value = HomeUiState(isLoading = false, error = e.message)
            }
        }
    }

    fun getItemById(id: Long): MediaItem? = itemCache[id]
}
