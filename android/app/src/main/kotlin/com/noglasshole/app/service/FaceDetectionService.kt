package com.noglasshole.app.service

import android.graphics.Bitmap
import android.graphics.RectF
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

data class DetectedFace(
    val id: Int,
    /** Normalized bounding box in image coordinates (0..1). Y-axis: 0=top. */
    val boundingBox: RectF,
    val confidence: Float,
    var isBlurred: Boolean = true
)

object FaceDetectionService {

    private val detector by lazy {
        val options = FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
            .enableTracking()
            .build()
        FaceDetection.getClient(options)
    }

    /**
     * Detect faces in a [Bitmap]. Returns normalized bounding boxes (0..1, top-left origin).
     * ML Kit's bounding boxes are in pixel space (top-left origin), so we normalize here.
     */
    suspend fun detectFaces(bitmap: Bitmap): List<DetectedFace> =
        suspendCancellableCoroutine { cont ->
            val image = InputImage.fromBitmap(bitmap, 0)
            detector.process(image)
                .addOnSuccessListener { faces ->
                    val w = bitmap.width.toFloat()
                    val h = bitmap.height.toFloat()
                    val result = faces.mapIndexed { index, face ->
                        val px = face.boundingBox
                        DetectedFace(
                            id = index,
                            boundingBox = RectF(
                                px.left / w,
                                px.top / h,
                                px.right / w,
                                px.bottom / h
                            ),
                            confidence = face.trackingId?.toFloat() ?: 1f
                        )
                    }
                    cont.resume(result)
                }
                .addOnFailureListener { e -> cont.resumeWithException(e) }
        }
}
