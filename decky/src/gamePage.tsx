import {
  afterPatch,
  appDetailsClasses,
  createReactTreePatcher,
  DialogButton,
  findInReactTree,
  Menu,
  MenuItem,
  showContextMenu,
} from "@decky/ui";
import { routerHook, toaster } from "@decky/api";
import { ReactElement, useEffect, useState } from "react";
import { backend, CatalogMatch } from "./backend";
import { addGame, launchGame, ownedShortcutIds, storeLabel } from "./opennow";
import { refresh, store, useSnapshot } from "./store";

const ROUTE = "/library/app/:appid";
const STEAM_GAME = 1;
const SHORTCUT = 1073741824;

interface PageApp {
  appId: number;
  shortcutTitle: string;
}

async function play(match: CatalogMatch) {
  const existing = store.get().state?.games.find((game) => game.variantId === match.variant.id);
  await launchGame(existing?.appId ?? (await addGame(match.game, match.variant)));
}

function PlayOnOpenNOW({ appId, shortcutTitle }: PageApp) {
  const [matches, setMatches] = useState<CatalogMatch[]>([]);
  const [busy, setBusy] = useState(false);
  const { status, state } = useSnapshot();
  useEffect(() => {
    backend.gamePageMatches(appId, shortcutTitle).then(setMatches).catch(() => setMatches([]));
  }, [appId, shortcutTitle]);
  if (!matches.length || !state?.preferences.gamePageButton || ownedShortcutIds(state).includes(appId)) return null;
  const run = (task: () => Promise<unknown>) => {
    setBusy(true);
    task()
      .catch((error) => toaster.toast({ title: "OpenNOW", body: error instanceof Error ? error.message : String(error) }))
      .finally(() => setBusy(false));
  };
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
      <Menu label="Play on OpenNOW">
        {matches.map((match) => (
          <MenuItem key={match.variant.id} onSelected={() => run(() => play(match))}>
            {storeLabel(match.variant.store)}
          </MenuItem>
        ))}
      </Menu>,
      event.currentTarget ?? window,
    );
  };
  const label = !status?.install ? "Install OpenNOW to stream" : busy ? "Starting…" : "Play on OpenNOW";
  return (
    <div style={{ padding: "0 2.8vw", marginTop: 16 }}>
      <DialogButton style={{ width: "auto", minWidth: 240 }} disabled={busy || !!status?.installProgress} onClick={onClick}>
        {label}
      </DialogButton>
    </div>
  );
}

function pageApp(overview: any): PageApp | undefined {
  if (typeof overview?.appid !== "number") return undefined;
  if (overview.app_type === STEAM_GAME) return { appId: overview.appid, shortcutTitle: "" };
  if (overview.app_type === SHORTCUT && typeof overview.display_name === "string") {
    return { appId: overview.appid, shortcutTitle: overview.display_name };
  }
  return undefined;
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
    ], (_: unknown, rendered?: ReactElement) => {
      if (!app) return rendered;
      const container = findInReactTree(rendered, (node: any) =>
        Array.isArray(node?.props?.children) && node?.props?.className?.includes(appDetailsClasses.InnerContainer));
      if (!container) return rendered;
      const children = container.props.children as ReactElement[];
      if (!children.some((child) => child?.key === "opennow-play")) {
        const panel = children.findIndex((child: any) => child?.props?.overview && child?.props?.onShowLaunchingDetails);
        children.splice(panel < 0 ? 1 : panel, 0, <PlayOnOpenNOW key="opennow-play" {...app} />);
      }
      return rendered;
    });
    afterPatch(routeProps, "renderFunc", patcher);
    return tree;
  });
  return () => routerHook.removePatch(ROUTE, patch);
}
