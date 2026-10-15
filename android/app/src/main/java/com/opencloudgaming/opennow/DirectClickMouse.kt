package com.opencloudgaming.opennow

import kotlin.math.roundToInt

/** Sends each direct touch as a host position, independent of the game's current cursor. */
internal class DirectClickMouse {
    var isPressed = false
        private set

    fun press(
        position: AbsoluteMousePosition?,
        sendPosition: (AbsoluteMousePosition) -> Boolean,
        setButton: (Boolean) -> Boolean,
    ): Boolean {
        if (isPressed || position == null || !sendPosition(position)) return false
        isPressed = setButton(true)
        return isPressed
    }

    fun move(position: AbsoluteMousePosition?, sendPosition: (AbsoluteMousePosition) -> Boolean): Boolean {
        if (!isPressed || position == null) return false
        return sendPosition(position)
    }

    fun release(setButton: ((Boolean) -> Boolean)?) {
        if (isPressed) setButton?.invoke(false)
        isPressed = false
    }
}

/** The absolute packet includes the decoded stream extent; view dimensions never go on the wire. */
internal fun directClickMousePosition(target: StreamPoint, width: Int, height: Int): AbsoluteMousePosition? {
    if (
        width !in 1..65535 || height !in 1..65535 ||
        !target.x.isFinite() || !target.y.isFinite()
    ) return null
    return AbsoluteMousePosition(
        x = target.x.coerceIn(0f, width.toFloat()).roundToInt(),
        y = target.y.coerceIn(0f, height.toFloat()).roundToInt(),
        width = width,
        height = height,
    )
}
