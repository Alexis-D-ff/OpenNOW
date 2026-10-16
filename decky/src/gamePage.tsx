import {
  afterPatch,
  appDetailsClasses,
  createReactTreePatcher,
  DialogButton,
  findInReactTree,
  Menu,
  MenuItem,
  playSectionClasses,
  showContextMenu,
  SteamSpinner,
} from "@decky/ui";
import { routerHook, toaster } from "@decky/api";
import { ReactElement, useEffect, useState, useSyncExternalStore } from "react";
import { FaCloud } from "react-icons/fa";
import { backend, CatalogMatch } from "./backend";
import { errorText } from "./format";
import { addGame, launchGame, ownedShortcutIds, shortcutName } from "./opennow";
import { refresh, store, useSnapshot } from "./store";
import { StoreIcon, storeLabel } from "./stores";

const ROUTE = "/library/app/:appid";
const STEAM_GAME = 1;
const SHORTCUT = 1073741824;
const BUTTON_KEY = "opennow-play";

const STYLE = `
.opennow-play {
  display: flex !important;
  align-items: center;
  gap: 14px;
  min-height: 60px;
  min-width: 240px !important;
  width: auto !important;
  margin: 0 0 0 12px !important;
  padding: 0 20px !important;
  border-radius: 2px !important;
  text-align: left;
  flex-shrink: 0;
  overflow: hidden;
}
.opennow-play .opennow-play-text { display: flex; flex-direction: column; line-height: 1.15; }
.opennow-play .opennow-play-title { font-size: 18px; font-weight: 500; }
.opennow-play .opennow-play-detail { font-size: 13px; opacity: 0.75; }
.opennow-play .opennow-play-progress { position: absolute; left: 0; bottom: 0; height: 5px; background: #1a9fff; }
`;

interface PageApp {
  appId: number;
  shortcutTitle: string;
}

const inPlayBar = new Set<number>();
const playBarListeners = new Set<() => void>();

function setInPlayBar(appId: number, present: boolean) {
  if (present) inPlayBar.add(appId);
  else inPlayBar.delete(appId);
  playBarListeners.forEach((listener) => listener());
}

function useInPlayBar(appId: number): boolean {
  return useSyncExternalStore(
    (listener) => {
      playBarListeners.add(listener);
      return () => playBarListeners.delete(listener);
    },
    () => inPlayBar.has(appId),
  );
}

async function play(match: CatalogMatch) {
  const existing = store.get().state?.games.find((game) => game.variantId === match.variant.id);
  const appId = existing?.appId ?? (await addGame(match.game, match.variant));
  await launchGame(appId, existing?.title ?? shortcutName(match.game, match.variant));
}

function useMatches(appId: number, shortcutTitle: string): CatalogMatch[] {
  const [matches, setMatches] = useState<CatalogMatch[]>([]);
  useEffect(() => {
    backend.gamePageMatches(appId, shortcutTitle).then(setMatches).catch(() => setMatches([]));
  }, [appId, shortcutTitle]);
  return matches;
}

function detailLabel(matches: CatalogMatch[], busy: boolean, installed: boolean, progress?: { phase: string; fraction: number } | null): string {
  if (progress) return progress.phase === "download" ? "Installing " + Math.round(progress.fraction * 100) + "%" : "Installing…";
  if (!installed) return "Install OpenNOW";
  if (busy) return "Starting…";
  if (matches.length > 1) return "Choose a version";
  return storeLabel(matches[0].variant.store) + " version";
}

function PlayOnOpenNOW({ appId, shortcutTitle, placement }: PageApp & { placement: "bar" | "row" }) {
  const matches = useMatches(appId, shortcutTitle);
  const [busy, setBusy] = useState(false);
  const { status, state } = useSnapshot();
  const inBar = useInPlayBar(appId);
  useEffect(() => {
    if (placement !== "bar") return;
    setInPlayBar(appId, true);
    return () => setInPlayBar(appId, false);
  }, [appId, placement]);
  if (placement === "row" && inBar) return null;
  if (!matches.length || !state?.preferences.gamePageButton || ownedShortcutIds(state).includes(appId)) return null;
  const run = (task: () => Promise<unknown>) => {
    setBusy(true);
    task()
      .catch((error) => toaster.toast({ title: "OpenNOW", body: errorText(error) }))
      .finally(() => setBusy(false));
  };
  const progress = status?.installProgress;
  const onClick = (event: MouseEvent) => {
    if (!status?.install) {
      run(() => backend.installOpenNOW().then(refresh));
      return;
    }
    if (matches.length === 1) {
      run(() => play(matches[0]));
      return;
    }
    showContextMenu(
      <Menu label={"Stream " + matches[0].game.title + " from"}>
        {matches.map((match) => (
          <MenuItem key={match.variant.id} onSelected={() => run(() => play(match))}>
            <span style={{ display: "flex", alignItems: "center", gap: 12 }}>
              <StoreIcon store={match.variant.store} size={18} />
              <span style={{ display: "flex", flexDirection: "column" }}>
                {storeLabel(match.variant.store)}
                {!shortcutTitle && match.variant.store === "STEAM" && (
                  <span style={{ fontSize: 12, opacity: 0.7 }}>In your Steam library</span>
                )}
              </span>
            </span>
          </MenuItem>
        ))}
      </Menu>,
      (event.currentTarget as EventTarget | null) ?? window,
    );
  };
  const button = (
    <DialogButton className="opennow-play" disabled={busy || !!progress} onClick={onClick} style={{ position: "relative" }}>
      <style>{STYLE}</style>
      {busy ? <SteamSpinner style={{ width: 22, height: 22, minHeight: 0, background: "none" }} /> : <FaCloud size={22} />}
      <span className="opennow-play-text">
        <span className="opennow-play-title">Play on OpenNOW</span>
        <span className="opennow-play-detail">{detailLabel(matches, busy, !!status?.install, progress)}</span>
      </span>
      {progress?.phase === "download" && <span className="opennow-play-progress" style={{ width: progress.fraction * 100 + "%" }} />}
    </DialogButton>
  );
  if (placement === "bar") return button;
  return <div style={{ padding: "0 2.8vw", marginTop: 16, display: "flex" }}>{button}</div>;
}

function pageApp(overview: any): PageApp | undefined {
  if (typeof overview?.appid !== "number") return undefined;
  if (overview.app_type === STEAM_GAME) return { appId: overview.appid, shortcutTitle: "" };
  if (overview.app_type === SHORTCUT && typeof overview.display_name === "string") {
    return { appId: overview.appid, shortcutTitle: overview.display_name };
  }
  return undefined;
}

function hasClass(node: any, className: string): boolean {
  return typeof node?.props?.className === "string" && node.props.className.split(" ").includes(className);
}

function insertOnce(children: unknown, element: ReactElement, index: (list: any[]) => number) {
  if (!Array.isArray(children) || children.some((child: any) => child?.key === BUTTON_KEY)) return;
  const at = index(children);
  children.splice(at < 0 ? children.length : at, 0, element);
}

export function patchGamePage(): () => void {
  const patch = routerHook.addPatch(ROUTE, (tree: any) => {
    const routeProps = findInReactTree(tree, (node: any) => node?.renderFunc);
    if (!routeProps) return tree;
    let app: PageApp | undefined;
    const patcher = createReactTreePatcher([
      (inner: any) => {
        const children = findInReactTree(inner, (node: any) => node?.props?.children?.props?.overview)?.props?.children;
        app = pageApp(children?.props?.overview);
        return children;
      },
      (rendered: any) => {
        if (!app) return null;
        const container = findInReactTree(rendered, (node: any) =>
          Array.isArray(node?.props?.children) && hasClass(node, appDetailsClasses.InnerContainer));
        if (container) {
          insertOnce(container.props.children, <PlayOnOpenNOW key={BUTTON_KEY} {...app} placement="row" />, (children) =>
            children.findIndex((child: any) => child?.props?.overview && child?.props?.onShowLaunchingDetails) + 1);
        }
        return findInReactTree(rendered, (node: any) => node?.props?.overview && node?.props?.onShowLaunchingDetails);
      },
    ], (_: unknown, rendered?: ReactElement) => {
      if (!app) return rendered;
      const buttons = findInReactTree(rendered, (node: any) => hasClass(node, playSectionClasses.AppButtonsContainer));
      if (buttons) insertOnce(buttons.props.children, <PlayOnOpenNOW key={BUTTON_KEY} {...app} placement="bar" />, () => 1);
      return rendered;
    }, "OpenNOW game page");
    afterPatch(routeProps, "renderFunc", patcher);
    return tree;
  });
  return () => routerHook.removePatch(ROUTE, patch);
}
