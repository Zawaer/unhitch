# Clamshell

**Your MacBook keeps your headphones when you shut the lid. Clamshell hands them back.**

Close your laptop, walk off with your headphones, and the Mac is still holding the
Bluetooth link. On headsets that juggle two sources well you might never notice. On
everything else it shows up as a call routed to a closed laptop in your bag, playback
that stutters when you hit play on your phone, or a headset that just refuses to switch.

The usual fix is to turn Bluetooth off on sleep — which also switches off **Find My's
offline finding network**, the thing that lets a closed, sleeping Mac be located by
other Apple devices passing nearby. That is a bad trade.

Clamshell disconnects only the devices you pick. The Bluetooth radio is never touched,
so Find My keeps working exactly as before.

<br>

## What it does

- Sits in the menu bar. No window, no Dock icon, no preferences file to edit.
- Lists your paired Bluetooth devices. Tick the ones that should let go on lid close.
- Drops those links when you close the lid, when the Mac sleeps, or both.
- Keeps dropping them while the lid stays shut — so earbuds pulled out of their case
  an hour later reconnect to your phone, not to the laptop in your bag.
- Optionally reconnects them when you open the lid again.

Everything else is left alone: your keyboard, your mouse, your trackpad, and the radio
itself.

<br>

## Install

Download `Clamshell.zip` from [Releases](https://github.com/Zawaer/clamshell/releases),
unzip it, and drag `Clamshell.app` to your Applications folder.

The app is signed locally rather than notarized, so the first launch needs one extra
step: **right-click the app → Open → Open**. macOS remembers the choice and every launch
after that is a normal double-click.

Then click the menu bar icon, tick your headphones, and you are done. There is no
account, no onboarding, and nothing else to configure.

<br>

## Build from source

Requires Xcode command line tools. Nothing else — no Homebrew, no dependencies.

```sh
git clone https://github.com/Zawaer/clamshell.git
cd clamshell
make install
```

`make install` builds the app, generates the icon, signs it locally, and puts it in
`/Applications`. Other targets:

| Target | What it does |
| --- | --- |
| `make app` | Build `dist/Clamshell.app` without installing |
| `make run` | Build and launch from `dist/` |
| `make zip` | Package `dist/Clamshell.zip` for a release |
| `make uninstall` | Quit and remove the installed app |
| `make clean` | Remove build products |

<br>

## How it works

Three signals drive the whole app:

**Lid state** comes from `AppleClamshellState` on `IOPMrootDomain`, watched through an
IOKit interest notification. This is tracked separately from sleep on purpose — a
MacBook driving an external display stays wide awake with the lid shut, and that is
exactly when a headset silently re-attaching is most irritating.

**Sleep** comes from `IORegisterForSystemPower` rather than the friendlier
`NSWorkspace.willSleepNotification`, because the low-level API lets the app hold off
acknowledging sleep until the disconnect has actually landed. Acknowledging late is
fine; sleeping with the headset still attached is not.

**Connections** come from `IOBluetoothDevice.register(forConnectNotifications:)`. While
the lid is shut, any watched device that connects gets hung up on immediately.

Disconnecting is `IOBluetoothDevice.closeConnection()` — one link, not the radio. It
returns before the link is really gone (about 2.4 seconds on an M3 Air with an A2DP
headset), so the app polls until the device actually reports itself disconnected and
retries if it does not.

<br>

## Checking what it did

Clamshell logs every decision it makes to the unified log, which is the closest thing
a menu bar app has to showing its work:

```sh
log stream --predicate 'subsystem == "com.zawaer.clamshell"'
```

Close the lid, open it again, and you should see the lid transitions and each
disconnect land.

<br>

## Notes and limits

- **Find My is unaffected.** Clamshell never enables, disables, or reconfigures the
  Bluetooth radio. Offline finding keeps broadcasting from a closed, sleeping Mac.
  This is the entire reason the app exists instead of a two-line `blueutil` script.
- **Reconnect on lid open is off by default.** If your headphones moved to your phone
  while you were away, having the Mac grab them back the moment you sit down is its own
  small annoyance. Turn it on if you want it.
- **A device can only be dropped while the Mac is running code.** If earbuds connect
  during deep sleep, the Mac has to surface far enough to schedule the app before the
  link is dropped. In practice a connection wakes the machine enough for this; in a very
  deep sleep state the drop happens at the next wake instead.
- **Macs without a lid** (mini, Studio, iMac) hide the lid trigger and use the sleep
  trigger only.

<br>

## License

MIT. See [LICENSE](LICENSE).
