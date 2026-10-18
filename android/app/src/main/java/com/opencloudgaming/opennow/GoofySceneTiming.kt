package com.opencloudgaming.opennow

internal const val GOOFY_SCENE_DURATION_MILLIS = 8_000L
internal const val GOOFY_LOGO_MESSAGE_DURATION_MILLIS = 4_500L

/** One clock owns the gag, so a dropped frame cannot leave a bolt or a peeker behind. */
internal data class GoofySceneCue(
    val peekerReveal: Float,
    val showBugMessage: Boolean,
    val lightningProgress: Float?,
    val companionAiming: Boolean,
)

internal fun goofySceneCue(elapsedMillis: Long): GoofySceneCue {
    val time = elapsedMillis.coerceAtLeast(0L) % GOOFY_SCENE_DURATION_MILLIS
    return GoofySceneCue(
        peekerReveal = when {
            time < 700L -> time / 700f
            time < 3_650L -> 1f
            time < 4_000L -> 1f - (time - 3_650L) / 350f
            else -> 0f
        },
        showBugMessage = time in 700L until 3_650L,
        lightningProgress = if (time in 3_300L until 3_900L) (time - 3_300L) / 600f else null,
        companionAiming = time in 2_950L until 4_000L,
    )
}

internal data class MascotBubblePlacement(val x: Float, val y: Float, val above: Boolean, val tailX: Float)

/** Keep the entire bubble readable, and keep its tail aimed at the actual speaker near corners. */
internal fun mascotBubblePlacement(
    viewportWidth: Float,
    viewportHeight: Float,
    bubbleWidth: Float,
    bubbleHeight: Float,
    speakerX: Float,
    speakerY: Float,
    speakerHalfHeight: Float,
): MascotBubblePlacement {
    val x = (speakerX - bubbleWidth / 2f).coerceIn(0f, (viewportWidth - bubbleWidth).coerceAtLeast(0f))
    val above = speakerY >= bubbleHeight + speakerHalfHeight + 12f
    val y = (if (above) speakerY - speakerHalfHeight - bubbleHeight - 10f
        else speakerY + speakerHalfHeight + 10f)
        .coerceIn(0f, (viewportHeight - bubbleHeight).coerceAtLeast(0f))
    val inset = minOf(16f, bubbleWidth / 2f)
    return MascotBubblePlacement(x, y, above, (speakerX - x).coerceIn(inset, bubbleWidth - inset))
}
