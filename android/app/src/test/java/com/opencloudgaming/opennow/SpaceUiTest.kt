package com.opencloudgaming.opennow

import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import org.junit.Assert.*
import org.junit.Test

class SpaceUiTest {
    @Test fun existingAndNewInstallsStartOutsideTheExperiment() {
        assertFalse(AppSettings().experimentalSpaceUi)
        assertFalse(OpenNowJson.decodeFromString<AppSettings>("{}").experimentalSpaceUi)
        val restored = OpenNowJson.decodeFromString<AppSettings>(
            OpenNowJson.encodeToString(AppSettings(experimentalSpaceUi = true)),
        )
        assertTrue(restored.experimentalSpaceUi)
    }

    @Test fun bothOptInAndControllerAreRequiredAndStreamingAlwaysUsesTheStreamUi() {
        for (page in AppPage.entries) {
            for (optIn in listOf(false, true)) for (controller in listOf(false, true)) {
                assertEquals(optIn && controller && page != AppPage.Stream, shouldUseSpaceUi(optIn, controller, page))
            }
        }
        val saved = AppSettings(experimentalSpaceUi = true)
        assertTrue(shouldUseSpaceUi(saved.experimentalSpaceUi, true, AppPage.Home))
        assertFalse(shouldUseSpaceUi(saved.experimentalSpaceUi, false, AppPage.Home))
        assertTrue(shouldUseSpaceUi(saved.experimentalSpaceUi, true, AppPage.Home))
    }

    @Test fun libraryKeepsItsSearchFiltersAndOrdering() {
        val games = listOf(
            GameInfo(id = "1", title = "Zenith", availableStores = listOf("STEAM"), isInLibrary = true),
            GameInfo(id = "2", title = "Astral", availableStores = listOf("EPIC"), isInLibrary = true),
            GameInfo(id = "3", title = "Astral Echo", availableStores = listOf("STEAM"), isInLibrary = true),
        )
        val state = OpenNowUiState(page = AppPage.Library, libraryGames = games, librarySortId = LIBRARY_SORT_TITLE)
        assertEquals(listOf("2", "3", "1"), spaceUiGames(state).map { it.id })
        assertEquals(listOf("2", "3"), spaceUiGames(state.copy(librarySearch = "astral")).map { it.id })
        val steamFilter = libraryStoreFilterOptions(games).first { it.rawId == "STEAM" }.id
        assertEquals(listOf("3"), spaceUiGames(state.copy(librarySearch = "astral", libraryFilterIds = listOf(steamFilter))).map { it.id })
    }

    @Test fun storeUsesTheSameCatalogFallbackAsTheRegularHome() {
        val game = GameInfo(id = "catalog", title = "Catalog game")
        val fallback = OpenNowUiState(catalogResult = CatalogBrowseResult(listOf(game)))
        assertEquals(listOf(game), spaceUiGames(fallback))
        val current = GameInfo(id = "query", title = "Query result")
        assertEquals(listOf(current), spaceUiGames(fallback.copy(games = listOf(current))))
    }
}
