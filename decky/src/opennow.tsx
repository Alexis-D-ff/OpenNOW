import { ConfirmModal, Navigation, showModal } from "@decky/ui";
import { toaster } from "@decky/api";
import { backend, CatalogGame, CatalogVariant, PluginState } from "./backend";
import * as steam from "./steam";
import { storeLabel } from "./stores";
import { refresh, store } from "./store";

const LAUNCHER_NAME = "OpenNOW";

export function ownedShortcutIds(state: PluginState): number[] {
  return [state.launcherAppId, ...state.games.map((game) => game.appId)].filter((id): id is number => id !== null);
}

export function runningShortcut(state: PluginState): number | null {
  return ownedShortcutIds(state).find((appId) => steam.isRunning(appId)) ?? null;
}

export async function ensureLauncher(): Promise<number> {
  const state = await backend.getState();
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

export async function recreateLauncher() {
  const state = store.get().state ?? (await backend.getState());
  if (state.launcherAppId !== null) {
    await steam.removeShortcut(state.launcherAppId);
    await backend.setLauncher(null);
    await refresh();
  }
  await ensureLauncher();
  toaster.toast({ title: "OpenNOW", body: "Re-created OpenNOW in your library" });
}

export async function launchOpenNOW() {
  steam.launch(await ensureLauncher());
}

function confirmEndSession(title: string, okText: string): Promise<boolean> {
  return new Promise((resolve) => {
    showModal(
      <ConfirmModal
        strTitle={title}
        strDescription="The game you're streaming in OpenNOW will end."
        strOKButtonText={okText}
        onOK={() => resolve(true)}
        onCancel={() => resolve(false)}
      />,
    );
  });
}

const EXIT_TIMEOUT_MS = 15000;
const START_TIMEOUT_MS = 30000;

async function stopOpenNOW() {
  const state = store.get().state;
  const running = state ? runningShortcut(state) : null;
  if (running !== null) steam.terminate(running);
  await backend.closeOpenNOW();
  if (running !== null && !(await steam.waitForExit(running, EXIT_TIMEOUT_MS))) {
    throw new Error("OpenNOW didn't close. Try again.");
  }
  await refresh();
  if (store.get().status?.running) throw new Error("OpenNOW didn't close. Try again.");
}

async function endSessionFor(title: string): Promise<boolean> {
  const state = store.get().state;
  if ((state ? runningShortcut(state) : null) === null && !store.get().status?.running) return true;
  if (!(await confirmEndSession("Switch to " + title + "?", "Switch game"))) return false;
  await stopOpenNOW();
  return true;
}

export async function launchGame(appId: number, title: string) {
  await refresh();
  const state = store.get().state;
  if (state && runningShortcut(state) === appId) {
    Navigation.CloseSideMenus();
    return;
  }
  if (await endSessionFor(title)) steam.launch(appId);
}

export async function playOnOpenNOW(game: CatalogGame, variant: CatalogVariant) {
  const launcher = await ensureLauncher();
  await refresh();
  if (!(await endSessionFor(shortcutName(game, variant)))) return;
  steam.applyLaunchCommand(launcher, LAUNCHER_NAME, await backend.launchCommand(variant.id, game.title));
  try {
    steam.launch(launcher);
    await steam.waitForStart(launcher, START_TIMEOUT_MS);
  } finally {
    steam.applyLaunchCommand(launcher, LAUNCHER_NAME, await backend.launchCommand());
  }
}

export async function closeOpenNOW() {
  if (await confirmEndSession("Close OpenNOW?", "Close OpenNOW")) await stopOpenNOW();
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
