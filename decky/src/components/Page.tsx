import {
  ButtonItem,
  DialogButton,
  Field,
  Focusable,
  SidebarNavigation,
  Spinner,
  TextField,
  ToggleField,
} from "@decky/ui";
import { openFilePicker, toaster } from "@decky/api";
import { FileSelectionType } from "@decky/api";
import { useEffect, useRef, useState } from "react";
import { backend, CatalogGame, PreferenceKey } from "../backend";
import { addGame, launchGame, removeGame, storeLabel, syncShortcuts } from "../opennow";
import { ROUTE } from "../routes";
import { refresh, useSnapshot } from "../store";
import { statusLine } from "./QuickAccess";

function report(error: unknown) {
  toaster.toast({ title: "OpenNOW", body: error instanceof Error ? error.message : String(error) });
}

function AddGames() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<CatalogGame[]>([]);
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const { state } = useSnapshot();
  const latest = useRef(0);
  useEffect(() => {
    const request = ++latest.current;
    if (!query.trim()) {
      setResults([]);
      return;
    }
    setSearching(true);
    const timer = setTimeout(() => {
      backend.searchCatalog(query)
        .then((games) => request === latest.current && (setResults(games), setError(null)))
        .catch((failure) => request === latest.current && setError(String(failure)))
        .finally(() => request === latest.current && setSearching(false));
    }, 250);
    return () => clearTimeout(timer);
  }, [query]);
  const added = new Set(state?.games.map((game) => game.variantId));
  return (
    <>
      <TextField label="Search GeForce NOW" value={query} onChange={(event) => setQuery(event.target.value)} />
      {searching && <Spinner style={{ height: 24 }} />}
      {error && <Field description={error} />}
      {!searching && query.trim() && !error && results.length === 0 && <Field description="No GeForce NOW games match." />}
      {results.map((game) => (
        <Field key={game.id} label={game.title} icon={game.art.grid ? <img src={game.art.grid} height={48} /> : undefined}>
          <Focusable style={{ display: "flex", gap: 8 }}>
            {game.variants.map((variant) => (
              <DialogButton
                key={variant.id}
                style={{ minWidth: 0, width: "auto", padding: "0 16px" }}
                disabled={added.has(variant.id) || busy !== null}
                onClick={() => {
                  setBusy(variant.id);
                  addGame(game, variant).catch(report).finally(() => setBusy(null));
                }}
              >
                {added.has(variant.id) ? "Added" : busy === variant.id ? "Adding…" : "Add · " + storeLabel(variant.store)}
              </DialogButton>
            ))}
          </Focusable>
        </Field>
      ))}
    </>
  );
}

function YourGames() {
  const { state } = useSnapshot();
  if (!state?.games.length) return <Field description="Games you add appear in your Steam library and here." />;
  return (
    <>
      {state.games.map((game) => (
        <Field key={game.appId} label={game.title} description={storeLabel(game.store)}
          icon={game.art ? <img src={game.art} height={48} /> : undefined}>
          <Focusable style={{ display: "flex", gap: 8 }}>
            <DialogButton style={{ minWidth: 0, width: "auto", padding: "0 16px" }} onClick={() => launchGame(game.appId).catch(report)}>
              Play
            </DialogButton>
            <DialogButton style={{ minWidth: 0, width: "auto", padding: "0 16px" }} onClick={() => removeGame(game.appId).catch(report)}>
              Remove
            </DialogButton>
          </Focusable>
        </Field>
      ))}
    </>
  );
}

const PREFERENCES: [PreferenceKey, string, string][] = [
  ["consoleLayout", "Open in Game Mode layout", "Start OpenNOW with its controller interface"],
  ["collection", "Add shortcuts to an \"OpenNOW\" collection", "Keeps OpenNOW games together in your library"],
  ["gamePageButton", "Play on OpenNOW button", "Show it on Steam games that are on GeForce NOW"],
];

function Settings() {
  const { status, state } = useSnapshot();
  const [checking, setChecking] = useState(false);
  const preference = (key: PreferenceKey, value: boolean) =>
    backend.setPreference(key, value).then(key === "consoleLayout" ? syncShortcuts : refresh).catch(report);
  const pickPath = () =>
    openFilePicker(FileSelectionType.FILE, "/home")
      .then((result) => backend.setCustomPath(result.realpath))
      .then(syncShortcuts)
      .catch(report);
  const install = status?.install;
  return (
    <>
      <Field label="OpenNOW" description={statusLine(status)} />
      {install && <Field label="Location" description={install.path} />}
      <ButtonItem
        label="Updates"
        description={status?.release ? (status.release.updateAvailable ? "OpenNOW " + status.release.version + " is available" : "Up to date") : undefined}
        disabled={checking}
        onClick={() => {
          setChecking(true);
          backend.checkUpdate().then(refresh).catch(report).finally(() => setChecking(false));
        }}
      >
        {checking ? "Checking…" : "Check now"}
      </ButtonItem>
      <ButtonItem
        label="OpenNOW location"
        description={state?.customPath || "Found automatically"}
        onClick={pickPath}
      >
        Choose…
      </ButtonItem>
      {state?.customPath && (
        <ButtonItem label="Use automatic detection" onClick={() => backend.setCustomPath("").then(syncShortcuts).catch(report)}>
          Reset
        </ButtonItem>
      )}
      {PREFERENCES.map(([key, label, description]) => (
        <ToggleField key={key} label={label} description={description} checked={state?.preferences[key] ?? true}
          onChange={(value) => preference(key, value)} />
      ))}
      <ButtonItem label="GeForce NOW catalog" onClick={() =>
        backend.refreshCatalog().then((count) => toaster.toast({ title: "OpenNOW", body: count + " games in the catalog" })).catch(report)}>
        Refresh
      </ButtonItem>
      <Field label="Plugin version" description={status?.pluginVersion} />
      <Field label="Log file" description={status?.logPath} />
    </>
  );
}

export function OpenNOWPage() {
  useEffect(() => {
    refresh();
  }, []);
  return (
    <SidebarNavigation
      title="OpenNOW"
      showTitle
      pages={[
        { title: "Add games", route: ROUTE + "/add", content: <AddGames /> },
        { title: "Your games", route: ROUTE + "/games", content: <YourGames /> },
        { title: "Settings", route: ROUTE + "/settings", content: <Settings /> },
      ]}
    />
  );
}
