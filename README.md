# ChatGPT/Codex Usage

**Your ChatGPT/Codex allowance. Always in sight.**

A small native macOS menu bar app that keeps your **remaining 5-hour and weekly ChatGPT/Codex allowance, and both exact reset times**, visible without clicking.

![ChatGPT/Codex Usage running in the macOS menu bar](docs/assets/menu-bar.png)

[Introduction & installation](https://swihpi.github.io/codex-usage-menubar/) · [Install with ChatGPT/Codex](#install-with-chatgptcodex) · [Manual installation](#manual-installation)

## What it does

- Shows percentages **remaining**, matching the ChatGPT/Codex app: `5h 78% · 15 Oct 14:34 | Week 97% · 22 Oct 09:34`.
- Uses local reset dates with short month names; the click menu includes the year.
- Refreshes every two minutes and after wake, with manual refresh available.
- Marks saved readings as stale when a request fails.
- Shows a small amber dot at 20% remaining or below, and red at 10% or below.
- Offers optional launch at login; it stays off unless you enable it.
- Runs in the menu bar, without a Dock icon.

Independent community project. Not affiliated with, endorsed by, or sponsored by OpenAI.

## Requirements

- macOS 13 or newer is the deployment target. Runtime verified on an Apple Silicon Mac running macOS 26; older macOS and Intel Macs have not been runtime-tested.
- Apple Command Line Tools with **Swift 5.9 or newer** to build. The script builds for your Mac's native architecture.
- ChatGPT/Codex desktop or CLI installed and signed in **with ChatGPT** on the same Mac. An API-key-only login does not supply ChatGPT plan allowance.
- Internet access for usage refreshes. No additional API key or subscription to this app.
- Enough menu bar space for the full label. A notch, many icons, or a foreground app with long menus can reduce available space.

## Install with ChatGPT/Codex

Open ChatGPT/Codex on your Mac and paste this instruction:

```text
Install ChatGPT/Codex Usage from https://github.com/swihpi/codex-usage-menubar on this Mac. Read its README and inspect script/install.sh and script/build_and_run.sh before running them. Use the latest stable source release, and keep the source checkout so I can update later. Check the requirements; if Apple's Command Line Tools are missing, guide me through installing them. Build from source, install in my user Applications folder using ./script/install.sh, and launch it. Run the installed app's --check diagnostic to confirm live remaining allowance and reset times. Never print or copy authentication tokens. Leave launch at login off unless I request it. Explain any limits you cannot verify.
```

ChatGPT/Codex may ask for permission to build, install, or launch the app. You may need to complete Apple's Command Line Tools installer yourself. This is an assisted source installation, not a one-click installer.

## Manual installation

Install Apple's Command Line Tools if needed:

```sh
xcode-select --install
```

After installation finishes:

```sh
git clone https://github.com/swihpi/codex-usage-menubar.git
cd codex-usage-menubar
git checkout v1.0.1
./script/install.sh
```

This builds and locally signs the app, copies it to `~/Applications/Codex Usage.app`, and launches it. No `sudo`, Homebrew, Apple Developer membership, or full Xcode app is required. Swift 5.9+ is required; use a newer compatible toolchain if your installed tools are older.

Alternatively, download the source ZIP from a [release](https://github.com/swihpi/codex-usage-menubar/releases), extract it, open Terminal in that folder, and run `./script/install.sh`.

Custom location or build without launching:

```sh
./script/install.sh --destination "$HOME/Applications" --no-launch
./script/build_and_run.sh --build
```

There is no prebuilt binary or DMG. The app is locally ad-hoc signed during the build, not Developer ID signed or notarized for downloadable binary distribution. The scripts do not disable Gatekeeper or alter security settings.

## Verify, use, and configure

```sh
"$HOME/Applications/Codex Usage.app/Contents/MacOS/CodexUsage" --check
```

The diagnostic prints a live reading and exits, without opening another menu bar item. It queries usage only and does not start an AI turn.

Click the label for **Refresh now**, **Last updated**, **Open ChatGPT/Codex**, **Launch at login**, or **Quit**. The percentages always mean remaining allowance. Reset times come from the service, not a locally invented schedule. A missing window is shown as unavailable.

The helper is discovered in common ChatGPT/Codex and ChatGPT application bundles under `/Applications` and `~/Applications`, or at `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`, and `~/.local/bin/codex`. No configuration is normally needed.

## Troubleshooting

- **Helper not found:** install ChatGPT/Codex in a standard location, or install the ChatGPT/Codex CLI in a supported location. Open and sign into ChatGPT/Codex, then refresh.
- **Sign-in or service error:** open ChatGPT/Codex and confirm that it can show your account's usage. The desktop and CLI must use the account you intend to monitor. Refresh again.
- **Stale:** the last reading is retained. Check the connection and refresh. The app never converts an error into 0%.
- **No menu bar item:** leave fullscreen, quit duplicate copies, and check menu bar space. Hold Command and drag an existing menu bar item to rearrange it if necessary.
- **Launch at login needs approval:** check System Settings → General → Login Items. Install in a stable location before enabling it.
- **Future ChatGPT/Codex changes:** the app-server protocol may change. Report the app/tool versions and error wording in an issue, without credentials or private logs.

## Update and uninstall

Quit ChatGPT/Codex Usage, then update the source checkout to the desired release and rerun `./script/install.sh`. Updates are manual; there is no auto-updater.

To uninstall, turn off **Launch at login**, quit the app, and move `~/Applications/Codex Usage.app` to the Trash. The source checkout can also be removed. The only app preference data is its last usage snapshot, stored under `com.swi.codexusage`.

## Privacy and implementation

Native Swift/AppKit, with no third-party packages. The app starts the installed ChatGPT/Codex CLI's `app-server` over a private stdio pipe, initializes it, and calls `account/rateLimits/read`. It identifies windows by their reported durations (300 and 10,080 minutes), then converts used to remaining percentages.

The app does not directly read or copy your ChatGPT/Codex credential files, and stores no authentication tokens. Authentication and network access remain with the installed ChatGPT/Codex helper. The app adds no analytics or developer-operated backend; ChatGPT/Codex retains its own behavior and settings. The screenshot is illustrative, not a live feed of the developer's account.

## Development

```sh
./script/build_and_run.sh          # build and launch
./script/build_and_run.sh --verify # build, launch, confirm process exists
./script/build_and_run.sh --build  # build only
```

Build output is in `outputs/` and is excluded from Git. The landing page is in `docs/`. GitHub Actions checks the build on macOS without account credentials; authenticated usage and on-screen appearance require a signed-in Mac.

## License

[MIT](LICENSE) · Created by [swihpi](https://github.com/swihpi).
