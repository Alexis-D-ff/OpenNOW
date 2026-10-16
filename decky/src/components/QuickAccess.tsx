import {
  ButtonItem,
  DropdownItem,
  Field,
  Navigation,
  PanelSection,
  PanelSectionRow,
  ProgressBarWithInfo,
  SliderField,
  ToggleField,
} from "@decky/ui";
import { toaster } from "@decky/api";
import { useEffect, useState } from "react";
import { backend, Codec, Status, StreamSettings, StreamValues } from "../backend";
import { closeOpenNOW, launchGame, launchOpenNOW } from "../opennow";
import { refresh, useSnapshot } from "../store";
import { ROUTE } from "../routes";

const QUICK_LAUNCH_LIMIT = 5;
const CODEC_LABELS: Record<Codec, string> = { auto: "Auto", av1: "AV1", h265: "H.265", h264: "H.264" };

function report(error: unknown) {
  toaster.toast({ title: "OpenNOW", body: error instanceof Error ? error.message : String(error) });
}

export function statusLine(status: Status | null): string {
  if (!status) return "Checking…";
  if (status.installProgress) return "Installing " + status.installProgress.version + "…";
  if (!status.install) return "Not installed";
  const kind = status.install.kind === "flatpak" ? "Flatpak" : status.install.kind === "appimage" ? "AppImage" : "Installed";
  const version = status.install.version ? " · " + status.install.version : "";
  return (status.running ? "Running · " : "") + kind + version;
}

function openPage(page: string) {
  Navigation.Navigate(ROUTE + "/" + page);
  Navigation.CloseSideMenus();
}

function InstallSection({ status }: { status: Status }) {
  const progress = status.installProgress;
  if (progress) {
    return (
      <PanelSectionRow>
        <ProgressBarWithInfo
          nProgress={progress.fraction * 100}
          sOperationText={progress.phase === "download" ? "Downloading OpenNOW " + progress.version : "Installing"}
          bottomSeparator="none"
        />
      </PanelSectionRow>
    );
  }
  const update = status.install && status.release?.updateAvailable && status.install.kind === "flatpak";
  if (status.install && !update) return null;
  return (
    <PanelSectionRow>
      <ButtonItem layout="below" onClick={() => backend.installOpenNOW().then(refresh).catch(report)}>
        {update ? "Update to " + status.release?.version : "Install OpenNOW"}
      </ButtonItem>
    </PanelSectionRow>
  );
}

function StreamSection() {
  const [settings, setSettings] = useState<StreamSettings | null>(null);
  const { status } = useSnapshot();
  useEffect(() => {
    backend.getStreamSettings().then(setSettings).catch(report);
  }, [status?.running, status?.install?.data_dir]);
  if (!settings || !status?.install) return null;
  const { values, options, locked } = settings;
  const change = <K extends keyof StreamValues>(key: K, value: StreamValues[K]) => {
    setSettings({ ...settings, values: { ...values, [key]: value } });
    backend.setStreamSetting(key, value).then((next) => setSettings({ ...settings, values: next })).catch((error) => {
      report(error);
      backend.getStreamSettings().then(setSettings);
    });
  };
  return (
    <PanelSection title="Stream">
      {locked && (
        <PanelSectionRow>
          <Field description={settings.error ?? "OpenNOW is open. Close it to change stream settings."} />
        </PanelSectionRow>
      )}
      <PanelSectionRow>
        <DropdownItem
          label="Resolution"
          disabled={locked}
          rgOptions={options.resolutions.map((value) => ({ data: value, label: value.replace("x", " × ") }))}
          selectedOption={values.resolution}
          onChange={(option) => change("resolution", option.data)}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <DropdownItem
          label="Frame rate"
          disabled={locked}
          rgOptions={options.frameRates.map((value) => ({ data: value, label: value + " FPS" }))}
          selectedOption={values.fps}
          onChange={(option) => change("fps", option.data)}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <SliderField
          label="Max bitrate"
          disabled={locked}
          value={values.maxBitrateMbps}
          min={options.bitrate[0]}
          max={options.bitrate[1]}
          step={5}
          showValue
          valueSuffix=" Mbps"
          onChange={(value) => change("maxBitrateMbps", value)}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <DropdownItem
          label="Codec"
          disabled={locked}
          rgOptions={options.codecs.map((value) => ({ data: value, label: CODEC_LABELS[value] }))}
          selectedOption={values.codec}
          onChange={(option) => change("codec", option.data)}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <ToggleField label="HDR" disabled={locked} checked={values.enableHdr} onChange={(value) => change("enableHdr", value)} />
      </PanelSectionRow>
      <PanelSectionRow>
        <ToggleField
          label="Steam Deck identity"
          description="Unlocks Deck resolutions and 90 FPS"
          disabled={locked}
          checked={values.identifyAsSteamDeck}
          onChange={(value) => change("identifyAsSteamDeck", value)}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <ToggleField
          label="Steam Big Picture mode"
          description="Ask game launchers for their controller UI"
          disabled={locked}
          checked={values.steamBigPictureMode}
          onChange={(value) => change("steamBigPictureMode", value)}
        />
      </PanelSectionRow>
    </PanelSection>
  );
}

export function QuickAccess() {
  const { status, state } = useSnapshot();
  useEffect(() => {
    refresh();
    const timer = setInterval(refresh, 3000);
    return () => clearInterval(timer);
  }, []);
  const games = state?.games.slice(0, QUICK_LAUNCH_LIMIT) ?? [];
  return (
    <>
      <PanelSection>
        <PanelSectionRow>
          <Field label="OpenNOW" description={statusLine(status)} />
        </PanelSectionRow>
        {status && <InstallSection status={status} />}
        {status?.install && (
          <PanelSectionRow>
            <ButtonItem
              layout="below"
              onClick={() => (status.running ? Navigation.CloseSideMenus() : launchOpenNOW().catch(report))}
            >
              {status.running ? "Return to OpenNOW" : "Launch OpenNOW"}
            </ButtonItem>
          </PanelSectionRow>
        )}
        {status?.running && (
          <PanelSectionRow>
            <ButtonItem layout="below" onClick={() => closeOpenNOW().catch(report)}>
              Close OpenNOW
            </ButtonItem>
          </PanelSectionRow>
        )}
      </PanelSection>
      {status?.install && (
        <PanelSection title="Quick launch">
          {games.map((game) => (
            <PanelSectionRow key={game.appId}>
              <ButtonItem layout="below" onClick={() => launchGame(game.appId, game.title).catch(report)}>
                {game.title}
              </ButtonItem>
            </PanelSectionRow>
          ))}
          <PanelSectionRow>
            <ButtonItem layout="below" onClick={() => openPage("add")}>
              {games.length ? "Add more games" : "Add games to your library"}
            </ButtonItem>
          </PanelSectionRow>
        </PanelSection>
      )}
      <StreamSection />
      <PanelSection>
        <PanelSectionRow>
          <ButtonItem layout="below" onClick={() => openPage("settings")}>
            Settings
          </ButtonItem>
        </PanelSectionRow>
      </PanelSection>
    </>
  );
}
