package com.opencloudgaming.opennow

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.opencloudgaming.opennow.ui.theme.LocalReduceMotion
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first

private val SpaceInk = Color(0xFF080E18)
private val SpaceWhite = Color(0xFFF4F7FC)
private val SpaceMuted = Color(0xFFB0BCCC)
private val SpaceIce = Color(0xFFB8E6EF)

/** A saved preference is never enough to enter a controller-only shell, including on cold start. */
internal fun shouldUseSpaceUi(enabled: Boolean, controllerConnected: Boolean, page: AppPage): Boolean =
    enabled && controllerConnected && page != AppPage.Stream

@Composable
internal fun SpaceUiSettingsToggle(checked: Boolean, controllerConnected: Boolean, onCheckedChange: (Boolean) -> Unit) {
    SettingSwitch(
        label = stringResource(R.string.space_ui_name),
        checked = checked,
        enabled = controllerConnected || checked,
        description = stringResource(
            if (controllerConnected) R.string.space_ui_description else R.string.space_ui_controller_required,
        ),
        onCheckedChange = { if (!it || controllerConnected) onCheckedChange(it) },
    )
    if (!controllerConnected) {
        Text(stringResource(R.string.space_ui_controller_required), color = MaterialTheme.colorScheme.onSurfaceVariant,
            style = MaterialTheme.typography.bodySmall)
    }
}

/** Shares catalog derivations with the regular shell; no second catalog or launch owner. */
internal fun spaceUiGames(state: OpenNowUiState): List<GameInfo> = if (state.page == AppPage.Library) {
    val terms = searchTermsFor(state.librarySearch)
    sortLibraryGames(favoriteOrderedGames(state.libraryGames, state.settings.favoriteGameIds), state.librarySortId)
        .filter { gameMatchesSearch(it, terms) && gameMatchesLibraryFilters(it, state.libraryFilterIds) }
} else {
    filterCatalogGamesForLocalControls(state.games.ifEmpty { state.catalogResult.games }, state.catalogFilterIds)
}

@Composable
internal fun SpaceUiScreen(
    state: OpenNowUiState,
    onNavigate: (AppPage) -> Unit,
    onSelectGame: (GameInfo) -> Unit,
    onRefresh: () -> Unit,
    onSearchChange: (String) -> Unit,
    onResumeSession: () -> Unit,
    inputEnabled: Boolean,
    settingsContent: @Composable () -> Unit,
    catalogControls: @Composable () -> Unit = {},
    libraryContent: @Composable () -> Unit = {},
    queueContent: @Composable () -> Unit = {},
) {
    val games = remember(state.page, state.games, state.catalogResult.games, state.libraryGames,
        state.catalogFilterIds, state.libraryFilterIds, state.librarySearch, state.librarySortId,
        state.settings.favoriteGameIds) { spaceUiGames(state) }
    var storeSelectedId by rememberSaveable { mutableStateOf<String?>(null) }
    var librarySelectedId by rememberSaveable { mutableStateOf<String?>(null) }
    val selectedId = if (state.page == AppPage.Library) librarySelectedId else storeSelectedId
    val game = games.firstOrNull { it.id == selectedId } ?: games.firstOrNull()
    var searchOpen by rememberSaveable(state.page) { mutableStateOf(false) }
    val query = if (state.page == AppPage.Library) state.librarySearch else state.catalogSearch
    val listState = rememberLazyListState()
    val selectedRequester = remember { FocusRequester() }
    val navigationRequester = remember { FocusRequester() }
    val searchRequester = remember { FocusRequester() }
    val reduceMotion = LocalReduceMotion.current
    val context = LocalContext.current
    var backdropUrl by remember { mutableStateOf(game?.let { gameTvBannerImageUrl(context, it) }) }
    LaunchedEffect(game?.id, reduceMotion) {
        // Let fast D-pad traversal settle before starting another full-width artwork request.
        if (!reduceMotion) delay(100)
        backdropUrl = game?.let { gameTvBannerImageUrl(context, it) }
    }
    val family = rememberPhysicalControllerFamily(enabled = true)
    val selectHint = if (family == AndroidControllerFamily.PlayStation) "×" else "A"
    val backHint = if (family == AndroidControllerFamily.PlayStation) "○" else "B"
    val tabsHint = if (family == AndroidControllerFamily.PlayStation) "L1 / R1" else "LB / RB"
    val pages = remember { listOf(AppPage.Home, AppPage.Library, AppPage.Settings) }
    val searchVisible = searchOpen || query.isNotBlank()
    val windowFocused = LocalWindowInfo.current.isWindowFocused
    LaunchedEffect(state.page, games.isNotEmpty(), inputEnabled, windowFocused) {
        if (inputEnabled && windowFocused) {
            if (games.isNotEmpty() && state.page != AppPage.Settings) {
                listState.scrollToItem(games.indexOfFirst { it.id == game?.id }.coerceAtLeast(0))
                snapshotFlow { listState.layoutInfo.visibleItemsInfo.any { it.key == game?.id } }.first { it }
                selectedRequester.requestFocus()
            } else {
                navigationRequester.requestFocus()
            }
        }
    }
    LaunchedEffect(searchOpen) {
        if (searchOpen) {
            searchRequester.requestFocus()
        }
    }
    BoxWithConstraints(
        Modifier.fillMaxSize().testTag("space-ui").background(SpaceInk)
            .onPreviewKeyEvent { event ->
                if (!inputEnabled || event.key !in listOf(Key.ButtonL1, Key.ButtonR1)) false
                else {
                    if (event.type == KeyEventType.KeyUp) {
                        val delta = if (event.key == Key.ButtonR1) 1 else -1
                        onNavigate(pages[(pages.indexOf(state.page) + delta + pages.size) % pages.size])
                    }
                    true
                }
            },
    ) {
        val compact = maxHeight < 500.dp
        val portrait = maxWidth < maxHeight
        val inset = if (compact) 22.dp else 36.dp
        if (state.page != AppPage.Settings) {
            // A single bounded image transition, never a video or an idle animation loop.
            Crossfade(backdropUrl, animationSpec = tween(if (reduceMotion) 0 else 320), label = "space-art") { url ->
                if (url != null) UrlImage(url, Modifier.fillMaxSize())
            }
        }
        Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(SpaceInk.copy(alpha = .96f), SpaceInk.copy(alpha = .30f)))))
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(SpaceInk.copy(alpha = .40f), Color.Transparent, SpaceInk))))
        Column(Modifier.fillMaxSize().padding(horizontal = inset, vertical = if (compact) 10.dp else 20.dp)) {
            Row(Modifier.fillMaxWidth().focusGroup(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(if (portrait) 8.dp else 14.dp)) {
                if (!portrait) {
                    Column(Modifier.padding(end = 18.dp)) {
                        Text("OPENNOW", color = SpaceWhite, fontSize = 15.sp, fontWeight = FontWeight.Bold, letterSpacing = 3.sp)
                        Text(stringResource(R.string.space_ui_name), color = SpaceIce, fontSize = 10.sp, letterSpacing = 2.sp)
                    }
                }
                pages.forEach { page ->
                    SpaceControl(
                        label = stringResource(when (page) {
                            AppPage.Home -> R.string.nav_store
                            AppPage.Library -> R.string.nav_library
                            else -> R.string.nav_settings
                        }),
                        active = state.page == page,
                        modifier = if (page == state.page) Modifier.focusRequester(navigationRequester) else Modifier,
                        onClick = { onNavigate(page) },
                    )
                }
                Spacer(Modifier.weight(1f))
                if (state.page != AppPage.Settings) {
                    SpaceControl(label = stringResource(R.string.nav_search), onClick = { searchOpen = !searchOpen }) {
                        Icon(Icons.Outlined.Search, contentDescription = null, modifier = Modifier.size(20.dp))
                    }
                    if (!portrait) SpaceControl(label = stringResource(R.string.space_ui_refresh), onClick = onRefresh) {
                        Icon(Icons.Outlined.Refresh, contentDescription = null, modifier = Modifier.size(20.dp))
                    }
                }
            }
            if (state.page == AppPage.Settings) {
                Box(Modifier.weight(1f).padding(top = 12.dp).clip(RoundedCornerShape(24.dp)).background(SpaceInk.copy(alpha = .85f))) {
                    settingsContent()
                }
            } else {
                if (searchVisible) {
                    NativeSearchField(query = query, onQueryChange = onSearchChange,
                        placeholder = stringResource(R.string.nav_search), searching = state.loadingGames,
                        focusRequester = searchRequester, gamepadImeMode = true,
                        modifier = Modifier.padding(top = 10.dp).fillMaxWidth(if (portrait) 1f else .6f))
                }
                state.error?.takeIf { it.isNotBlank() }?.let { error ->
                    Text(error, color = Color(0xFFFFB5A9), fontSize = 12.sp, maxLines = 2,
                        overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 8.dp))
                }
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = if (compact) 14.dp else 32.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Box(Modifier.size(5.dp).background(SpaceIce, CircleShape))
                        Text(stringResource(R.string.space_ui_experimental), color = SpaceIce, fontSize = 10.sp, letterSpacing = 2.sp)
                    }
                    Spacer(Modifier.height(if (compact) 10.dp else 22.dp))
                    if (state.activeSession != null) {
                        SpaceControl(label = stringResource(R.string.action_resume), onClick = onResumeSession)
                    }
                    if (game != null) {
                        Text(game.title, color = SpaceWhite, fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Light,
                            fontSize = if (compact) 32.sp else if (portrait) 38.sp else 54.sp,
                            lineHeight = if (compact) 36.sp else 58.sp, maxLines = 2, overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.fillMaxWidth(if (portrait) 1f else .72f))
                        val metadata = (game.genres.take(2) + listOfNotNull(game.publisherName)).joinToString("   /   ")
                        if (metadata.isNotBlank()) Text(metadata, color = SpaceIce, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (!compact) gameDescriptionForDetails(game)?.let { description ->
                            Text(description, color = SpaceMuted, fontSize = 14.sp, lineHeight = 22.sp,
                                maxLines = if (portrait) 3 else 2, overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(top = 16.dp).fillMaxWidth(if (portrait) 1f else .58f))
                        }
                        Spacer(Modifier.height(if (compact) 10.dp else 22.dp))
                        SpaceControl(label = stringResource(R.string.space_ui_view_game), filled = true, onClick = { onSelectGame(game) }) {
                            Icon(Icons.Outlined.SportsEsports, null, Modifier.size(19.dp))
                            Spacer(Modifier.width(10.dp))
                            Text(stringResource(R.string.space_ui_view_game), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        }
                    } else {
                        if (state.loadingGames) CircularProgressIndicator(color = SpaceIce, modifier = Modifier.size(28.dp))
                        else {
                            Text(stringResource(R.string.no_games_loaded), color = SpaceWhite, fontSize = 26.sp)
                            Text(stringResource(R.string.space_ui_empty), color = SpaceMuted, modifier = Modifier.padding(top = 12.dp))
                            SpaceControl(label = stringResource(R.string.space_ui_refresh), onClick = onRefresh)
                        }
                    }
                    if (state.page == AppPage.Library) libraryContent()
                }
                Row(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(if (state.page == AppPage.Library) R.string.nav_library else R.string.nav_store), color = SpaceMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                        Spacer(Modifier.weight(1f))
                        Text("${if (game == null) 0 else games.indexOf(game) + 1} / ${games.size}", color = SpaceMuted, fontSize = 11.sp)
                        Spacer(Modifier.width(12.dp))
                        catalogControls()
                }
                if (games.isNotEmpty()) {
                    LazyRow(state = listState, modifier = Modifier.fillMaxWidth().focusGroup().testTag("space-game-rail"),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        itemsIndexed(games, key = { _, item -> item.id }) { _, item ->
                            SpaceGameTile(game = item, selected = game?.id == item.id,
                                compact = compact, reduceMotion = reduceMotion,
                                modifier = if (game?.id == item.id) Modifier.focusRequester(selectedRequester) else Modifier,
                                onFocused = {
                                    if (state.page == AppPage.Library) librarySelectedId = item.id
                                    else storeSelectedId = item.id
                                }, onClick = { onSelectGame(item) })
                        }
                    }
                }
            }
            queueContent()
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(if (portrait) 14.dp else 24.dp)) {
                SpaceHint("✥", stringResource(R.string.space_ui_navigate))
                SpaceHint(selectHint, stringResource(R.string.space_ui_select))
                SpaceHint(backHint, stringResource(R.string.space_ui_back))
                if (!portrait) SpaceHint(tabsHint, stringResource(R.string.space_ui_tabs))
                Spacer(Modifier.weight(1f))
                if (!compact && !portrait) Text(stringResource(R.string.space_ui_controller_connected), color = SpaceMuted, fontSize = 10.sp)
            }
        }
    }
}

@Composable
private fun SpaceGameTile(game: GameInfo, selected: Boolean, compact: Boolean, reduceMotion: Boolean,
    modifier: Modifier, onFocused: () -> Unit, onClick: () -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(if (focused) 1.04f else 1f, tween(if (reduceMotion) 0 else 160), label = "space-tile")
    val shape = RoundedCornerShape(14.dp)
    val focusManager = LocalFocusManager.current
    Box(modifier.size(if (compact) 98.dp else 134.dp).graphicsLayer { scaleX = scale; scaleY = scale }
        .onFocusChanged { focused = it.isFocused; if (it.isFocused) onFocused() }
        .clip(shape).background(SpaceInk)
        .border(if (focused) 2.dp else 1.dp, if (focused) SpaceWhite else if (selected) SpaceIce.copy(alpha = .5f) else SpaceWhite.copy(alpha = .16f), shape)
        .onPreviewKeyEvent { event ->
            if (isTvActivateKey(event)) { onClick(); true } else handleDpadFocusMove(event, focusManager)
        }
        .clickable(onClick = onClick)
        .semantics { contentDescription = game.title; this.selected = selected }
        .testTag("space-game-${game.id}")) {
        UrlImage(catalogCardImageUrl(game, tvProfile = true, requestWidth = 272), Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, SpaceInk.copy(alpha = .92f)))))
        Text(game.title, color = SpaceWhite, fontSize = if (compact) 10.sp else 12.sp, lineHeight = 15.sp,
            fontWeight = FontWeight.Medium, maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.align(Alignment.BottomStart).padding(10.dp))
    }
}

@Composable
private fun SpaceControl(label: String, modifier: Modifier = Modifier, active: Boolean = false,
    filled: Boolean = false, onClick: () -> Unit, content: (@Composable RowScope.() -> Unit)? = null) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(50)
    val focusManager = LocalFocusManager.current
    Row(modifier.defaultMinSize(minHeight = 42.dp, minWidth = 42.dp)
        .onFocusChanged { focused = it.isFocused }
        .clip(shape).background(when { filled -> SpaceWhite; active -> SpaceWhite.copy(alpha = .12f); else -> Color.Transparent })
        .border(1.dp, if (focused) SpaceIce else Color.Transparent, shape)
        .onPreviewKeyEvent { event ->
            if (isTvActivateKey(event)) { onClick(); true } else handleDpadFocusMove(event, focusManager)
        }
        .clickable(onClick = onClick)
        .semantics { contentDescription = label; selected = active }
        .padding(horizontal = 16.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
        androidx.compose.runtime.CompositionLocalProvider(androidx.compose.material3.LocalContentColor provides if (filled) SpaceInk else SpaceWhite) {
            if (content != null) content()
            else Text(label, color = if (filled) SpaceInk else SpaceWhite, fontSize = 13.sp, fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal)
        }
    }
}

@Composable
private fun SpaceHint(button: String, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(button, color = SpaceWhite, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        Text(label, color = SpaceMuted, fontSize = 10.sp)
    }
}
