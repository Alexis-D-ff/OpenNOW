package com.opencloudgaming.opennow

import android.graphics.Bitmap
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.io.File

class SpaceUiInstrumentedTest {
    @get:Rule val compose = createComposeRule()
    private val games = listOf(
        GameInfo(id = "1", title = "Beyond the horizon", genres = listOf("Adventure", "Exploration"),
            description = "A new world is waiting. Find your next adventure and make it your own."),
        GameInfo(id = "2", title = "Nightfall"),
        GameInfo(id = "3", title = "The last frontier"),
        GameInfo(id = "4", title = "Velocity"),
        GameInfo(id = "5", title = "Echoes"),
        GameInfo(id = "6", title = "Worlds apart"),
        GameInfo(id = "7", title = "Aurora"),
        GameInfo(id = "8", title = "Solstice"),
    )

    @Test fun controllerFocusLaunchCallbackAndBumpersWork() {
        var state by mutableStateOf(OpenNowUiState(games = games, libraryGames = games))
        var selected: String? = null
        compose.setContent {
            MaterialTheme {
                SpaceUiScreen(state, onNavigate = { state = state.copy(page = it) },
                    onSelectGame = { selected = it.id }, onRefresh = {}, onSearchChange = {}, onResumeSession = {},
                    inputEnabled = true, settingsContent = { Text("Space settings") })
            }
        }
        compose.onNodeWithTag("space-game-1").assertIsFocused()
        compose.onNodeWithTag("space-game-1").performKeyInput { pressKey(Key.DirectionRight) }
        compose.onNodeWithTag("space-game-2").assertIsFocused()
        // MainActivity normalizes the controller's confirm button to D-pad center.
        compose.onNodeWithTag("space-game-2").performKeyInput { pressKey(Key.DirectionCenter) }
        compose.runOnIdle { assertEquals("2", selected) }
        compose.onNodeWithTag("space-ui").performKeyInput { pressKey(Key.ButtonR1) }
        compose.runOnIdle { assertEquals(AppPage.Library, state.page) }
        compose.onNodeWithTag("space-game-1").assertIsFocused()
        compose.onNodeWithTag("space-ui").performKeyInput { pressKey(Key.ButtonR1) }
        compose.onNodeWithText("Space settings").assertIsDisplayed()
        compose.onNodeWithTag("space-ui").performKeyInput { pressKey(Key.ButtonR1) }
        compose.runOnIdle { assertEquals(AppPage.Home, state.page) }
        compose.onNodeWithTag("space-game-2").assertIsFocused()
    }

    @Test fun emptyCatalogStillHasWorkingNavigationAndRefresh() {
        var refreshes = 0
        compose.setContent {
            MaterialTheme {
                SpaceUiScreen(OpenNowUiState(), onNavigate = {}, onSelectGame = {}, onRefresh = { refreshes++ },
                    onSearchChange = {}, onResumeSession = {}, inputEnabled = true, settingsContent = {})
            }
        }
        compose.onNodeWithText("No games loaded").assertIsDisplayed()
        compose.onAllNodesWithContentDescription("Refresh games").onLast().performClick()
        compose.runOnIdle { assertEquals(1, refreshes) }
        compose.onNodeWithTag("space-game-rail").assertDoesNotExist()
    }

    @Test fun controllerDisconnectFallsBackAndPreferenceCanStillBeDisabled() {
        var controller by mutableStateOf(false)
        var optIn by mutableStateOf(false)
        compose.setContent {
            MaterialTheme {
                Box(Modifier.fillMaxSize().testTag("gate")) {
                    if (shouldUseSpaceUi(optIn, controller, AppPage.Home)) Text("Space active")
                    else SpaceUiSettingsToggle(optIn, controller) { optIn = it }
                }
            }
        }
        compose.onNode(isToggleable()).assertIsNotEnabled()
        compose.runOnIdle { assertFalse(optIn); controller = true }
        compose.onNodeWithText("Space UI").performClick()
        compose.onNodeWithText("Space active").assertIsDisplayed()
        compose.runOnIdle { controller = false }
        compose.onNodeWithText("Space active").assertDoesNotExist()
        compose.runOnIdle { assertTrue(optIn) }
        compose.onNodeWithText("Space UI").performClick()
        compose.runOnIdle { assertFalse(optIn) }
    }

    @Test fun renderSpaceUi() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val art = "android.resource://${context.packageName}/${R.drawable.catalog_default_background}"
        val samples = games.map { it.copy(imageUrl = art, tvBannerUrl = art) }
        compose.setContent {
            MaterialTheme {
                SpaceUiScreen(OpenNowUiState(games = samples), onNavigate = {}, onSelectGame = {}, onRefresh = {},
                    onSearchChange = {}, onResumeSession = {}, inputEnabled = true, settingsContent = {})
            }
        }
        compose.onNodeWithTag("space-game-1").assertIsFocused()
        compose.waitForIdle()
        val bitmap = compose.onRoot().captureToImage().asAndroidBitmap()
        File(context.getExternalFilesDir(null), "space-ui-${bitmap.width}x${bitmap.height}.png").outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }
}
