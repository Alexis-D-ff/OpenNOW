import { toaster } from "@decky/api";
import { backend, CatalogGame, CatalogVariant, PluginState } from "./backend";
import * as steam from "./steam";
import { refresh, store } from "./store";

const LAUNCHER_NAME = "OpenNOW";

export function ownedShortcutIds(state: PluginState): number[] {
  return [state.launcherAppId, ...state.games.map((game) => game.appId)].filter((id): id is number => id !== null);
}

export function runningShortcut(state: PluginState): number | null {
  return ownedShortcutIds(state).find((appId) => steam.isRunning(appId)) ?? null;
}

export async function ensureLauncher(): Promise<number> {
  const state = store.get().state ?? (await backend.getState());
  const command = await backend.launchCommand();
  if (state.launcherAppId !== null && steam.overview(state.launcherAppId) !== null) {
    steam.applyLaunchCommand(state.launcherAppId, LAUNCHER_NAME, command);
    return state.launcherAppId;
  }
  const appId = await steam.createShortcut(LAUNCHER_NAME, command);
  if (state.preferences.collection) await steam.addToCollection(appId);
  await backend.setLauncher(appId);
  await refresh();
  return appId;
}

export async function launchOpenNOW() {
  steam.launch(await ensureLauncher());
}

export async function launchGame(appId: number) {
  const state = store.get().state;
  const running = state ? runningShortcut(state) : null;
  if (running === appId) return;
  if (running !== null) {
    steam.terminate(running);
  } else if (store.get().status?.running) {
    await backend.closeOpenNOW();
  }
  steam.launch(appId);
}

export async function closeOpenNOW() {
  const state = store.get().state;
  const running = state ? runningShortcut(state) : null;
  if (running !== null) steam.terminate(running);
  else await backend.closeOpenNOW();
  await refresh();
}

export function shortcutName(game: CatalogGame, variant: CatalogVariant): string {
  return game.variants.length > 1 ? game.title + " (" + storeLabel(variant.store) + ")" : game.title;
}

export async function addGame(game: CatalogGame, variant: CatalogVariant): Promise<number> {
  const existing = store.get().state?.games.find((entry) => entry.variantId === variant.id);
  if (existing && steam.overview(existing.appId) !== null) return existing.appId;
  const name = shortcutName(game, variant);
  const appId = await steam.createShortcut(name, await backend.launchCommand(variant.id, game.title));
  try {
    await steam.setCatalogArtwork(appId, game.art);
  } catch (error) {
    console.warn("OpenNOW: artwork failed", error);
  }
  if (store.get().state?.preferences.collection) await steam.addToCollection(appId);
  await backend.addGame(appId, variant.id, name, variant.store, game.art.grid);
  await refresh();
  toaster.toast({ title: "OpenNOW", body: "Added " + name + " to your library" });
  return appId;
}

export async function removeGame(appId: number) {
  await steam.removeShortcut(appId);
  await backend.removeGame(appId);
  await refresh();
}

export async function syncShortcuts() {
  const state = await backend.getState();
  const status = await backend.getStatus();
  if (!status.install) return;
  for (const game of state.games) {
    if (steam.overview(game.appId) === null) {
      await backend.removeGame(game.appId);
      continue;
    }
    steam.applyLaunchCommand(game.appId, game.title, await backend.launchCommand(game.variantId, game.title));
  }
  if (state.launcherAppId !== null && steam.overview(state.launcherAppId) !== null) {
    steam.applyLaunchCommand(state.launcherAppId, LAUNCHER_NAME, await backend.launchCommand());
  }
  await refresh();
}

const STORES: Record<string, string> = {
  STEAM: "Steam",
  EPIC: "Epic",
  UPLAY: "Ubisoft",
  ORIGIN: "EA",
  EA_APP: "EA",
  GOG: "GOG",
  BATTLENET: "Battle.net",
  XBOX: "Xbox",
  MICROSOFT: "Xbox",
  NONE: "Free to play",
};

export function storeLabel(store: string): string {
  return STORES[store] ?? store.charAt(0) + store.slice(1).toLowerCase().split("_").join(" ");
}
