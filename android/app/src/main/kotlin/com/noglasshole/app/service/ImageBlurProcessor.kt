package com.noglasshole.app.service

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import com.noglasshole.app.data.BlurStyle

object ImageBlurProcessor {

    /**
     * Apply face blur/obscure to [source] bitmap for all [faces] with [isBlurred] == true.
     * Returns a new bitmap; [source] is not modified.
     */
    fun blurFaces(
        source: Bitmap,
        faces: List<DetectedFace>,
        style: BlurStyle,
        intensity: Double,
        maskScale: Double
    ): Bitmap {
        val activeFaces = faces.filter { it.isBlurred }
        if (activeFaces.isEmpty()) return source

        val result = source.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(result)

        for (face in activeFaces) {
            val pixelRect = denormalize(face.boundingBox, result.width, result.height)
            val scaledRect = scaledRect(pixelRect, maskScale)

            when (style) {
                BlurStyle.GAUSSIAN -> applyBoxBlur(result, canvas, scaledRect, intensity)
                BlurStyle.PIXELATE -> applyPixelate(result, canvas, scaledRect, intensity)
                BlurStyle.SOLID_BLACK -> applySolidBlack(canvas, scaledRect)
            }
        }
        return result
    }

    // -------------------------------------------------------------------------
    // Gaussian (fast 3-pass box blur approximation)
    // -------------------------------------------------------------------------

    private fun applyBoxBlur(
        bitmap: Bitmap,
        canvas: Canvas,
        rect: RectF,
        intensity: Double
    ) {
        val radius = (intensity / 3.0).coerceIn(2.0, 50.0).toInt()

        // Crop the face region, blur it, then composite back with an elliptical feather mask
        val left = rect.left.toInt().coerceIn(0, bitmap.width - 1)
        val top = rect.top.toInt().coerceIn(0, bitmap.height - 1)
        val right = rect.right.toInt().coerceIn(left + 1, bitmap.width)
        val bottom = rect.bottom.toInt().coerceIn(top + 1, bitmap.height)

        val regionW = right - left
        val regionH = bottom - top
        val region = Bitmap.createBitmap(bitmap, left, top, regionW, regionH)
        val blurred = boxBlur(region, radius)

        // Draw blurred region through elliptical feather mask using layer save
        val saveCount = canvas.saveLayer(rect, null)

        canvas.drawBitmap(blurred, left.toFloat(), top.toFloat(), null)

        // Punch out (erase) the area outside the ellipse using DST_IN
        val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
        }
        maskPaint.shader = buildEllipticalGradient(rect)
        canvas.drawRect(rect, maskPaint)

        canvas.restoreToCount(saveCount)
    }

    /**
     * Three-pass horizontal/vertical box blur. No RenderScript, no deprecated APIs.
     */
    private fun boxBlur(src: Bitmap, radius: Int): Bitmap {
        var result = src.copy(Bitmap.Config.ARGB_8888, true)
        val w = result.width
        val h = result.height
        val pixels = IntArray(w * h)

        repeat(3) { // 3 passes ≈ Gaussian
            result.getPixels(pixels, 0, w, 0, 0, w, h)
            blurHorizontal(pixels, w, h, radius)
            blurVertical(pixels, w, h, radius)
            result.setPixels(pixels, 0, w, 0, 0, w, h)
        }
        return result
    }

    private fun blurHorizontal(pixels: IntArray, w: Int, h: Int, radius: Int) {
        val temp = IntArray(w)
        for (y in 0 until h) {
            val base = y * w
            var rSum = 0; var gSum = 0; var bSum = 0
            val extent = radius * 2 + 1

            for (x in -radius until radius + 1) {
                val px = pixels[base + x.coerceIn(0, w - 1)]
                rSum += Color.red(px); gSum += Color.green(px); bSum += Color.blue(px)
            }
            for (x in 0 until w) {
                temp[x] = Color.rgb(rSum / extent, gSum / extent, bSum / extent)
                val remove = pixels[base + (x - radius).coerceIn(0, w - 1)]
                val add    = pixels[base + (x + radius + 1).coerceIn(0, w - 1)]
                rSum += Color.red(add) - Color.red(remove)
                gSum += Color.green(add) - Color.green(remove)
                bSum += Color.blue(add) - Color.blue(remove)
            }
            temp.copyInto(pixels, base, 0, w)
        }
    }

    private fun blurVertical(pixels: IntArray, w: Int, h: Int, radius: Int) {
        val temp = IntArray(h)
        for (x in 0 until w) {
            var rSum = 0; var gSum = 0; var bSum = 0
            val extent = radius * 2 + 1

            for (y in -radius until radius + 1) {
                val px = pixels[y.coerceIn(0, h - 1) * w + x]
                rSum += Color.red(px); gSum += Color.green(px); bSum += Color.blue(px)
            }
            for (y in 0 until h) {
                temp[y] = Color.rgb(rSum / extent, gSum / extent, bSum / extent)
                val remove = pixels[(y - radius).coerceIn(0, h - 1) * w + x]
                val add    = pixels[(y + radius + 1).coerceIn(0, h - 1) * w + x]
                rSum += Color.red(add) - Color.red(remove)
                gSum += Color.green(add) - Color.green(remove)
                bSum += Color.blue(add) - Color.blue(remove)
            }
            for (y in 0 until h) { pixels[y * w + x] = temp[y] }
        }
    }

    // -------------------------------------------------------------------------
    // Pixelate
    // -------------------------------------------------------------------------

    private fun applyPixelate(
        bitmap: Bitmap,
        canvas: Canvas,
        rect: RectF,
        intensity: Double
    ) {
        val blockSize = (intensity / 5.0).coerceIn(4.0, 60.0).toInt()
        val left   = rect.left.toInt().coerceIn(0, bitmap.width - 1)
        val top    = rect.top.toInt().coerceIn(0, bitmap.height - 1)
        val right  = rect.right.toInt().coerceIn(left + 1, bitmap.width)
        val bottom = rect.bottom.toInt().coerceIn(top + 1, bitmap.height)

        val regionW = right - left
        val regionH = bottom - top
        val pixels = IntArray(regionW * regionH)
        bitmap.getPixels(pixels, 0, regionW, left, top, regionW, regionH)

        val paint = Paint()
        var bx = 0
        while (bx < regionW) {
            var by = 0
            while (by < regionH) {
                // Average the block
                var r = 0; var g = 0; var b = 0; var count = 0
                for (dx in 0 until blockSize) {
                    for (dy in 0 until blockSize) {
                        val px = (bx + dx).coerceAtMost(regionW - 1)
                        val py = (by + dy).coerceAtMost(regionH - 1)
                        val c = pixels[py * regionW + px]
                        r += Color.red(c); g += Color.green(c); b += Color.blue(c)
                        count++
                    }
                }
                paint.color = Color.rgb(r / count, g / count, b / count)
                canvas.drawRect(
                    (left + bx).toFloat(),
                    (top + by).toFloat(),
                    (left + bx + blockSize).toFloat().coerceAtMost(right.toFloat()),
                    (top + by + blockSize).toFloat().coerceAtMost(bottom.toFloat()),
                    paint
                )
                by += blockSize
            }
            bx += blockSize
        }
    }

    // -------------------------------------------------------------------------
    // Solid Black
    // -------------------------------------------------------------------------

    private fun applySolidBlack(canvas: Canvas, rect: RectF) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }
        val path = Path().apply {
            addOval(rect, Path.Direction.CW)
        }
        canvas.drawPath(path, paint)
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun denormalize(norm: RectF, w: Int, h: Int): RectF = RectF(
        norm.left * w,
        norm.top * h,
        norm.right * w,
        norm.bottom * h
    )

    private fun scaledRect(rect: RectF, scale: Double): RectF {
        val cx = rect.centerX()
        val cy = rect.centerY()
        val hw = rect.width() / 2 * scale.toFloat()
        val hh = rect.height() / 2 * scale.toFloat()
        return RectF(cx - hw, cy - hh, cx + hw, cy + hh)
    }

    private fun buildEllipticalGradient(rect: RectF): RadialGradient {
        // Use max(w,h)/2 as radius; stops go to 1.0 (edge of radius circle).
        // The feather starts at 70% and ends at 100% of the radius.
        val radius = maxOf(rect.width(), rect.height()) / 2f
        return RadialGradient(
            rect.centerX(), rect.centerY(), radius,
            intArrayOf(Color.WHITE, Color.WHITE, Color.TRANSPARENT),
            floatArrayOf(0f, 0.7f, 1f),
            Shader.TileMode.CLAMP
        )
    }
}
