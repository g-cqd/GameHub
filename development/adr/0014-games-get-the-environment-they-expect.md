---
status: accepted
date: 2026-10-31
---

# 0014: Games get the Windows environment they expect, so a Mac plays them as fully as a PC

This revises the first version (2026-10-15), which only allowed implementing real Windows behaviour and ruled out
anything that misreports the machine. The owner set the line on 2026-10-31.

## Context
Studios ship for Windows PCs. Many games check the environment as if no other machine existed:
- **GPU vendor and model:** a vendor id outside NVIDIA, AMD or Intel gets a refusal, a fallback renderer or the
  lowest presets.
- **CPU features** and **driver versions.**
- **Windows build and kernel interfaces:** anti-cheat and DRM loaders check these.
- **Markers of Wine.**

None of these checks exists to keep Mac players out. Macs were just never considered. The owner, verbatim: "we want
to run games, with their native environment, on mac, it might require sometimes to lie about what is the hardware,
but the intent is to play on mac when game studio basically don't take into account people also have macs, i just
want to run with the same amount of functionality on mac than on windows."

## Decision
**The goal is parity.** A game on the Mac has the same functionality as on a Windows PC: it starts, it offers the
same modes and settings, and it plays online if it plays online on Windows.

**What the game sees:**
- **Real behaviour first:** we implement what Windows really does wherever we can. This covers syscalls, kernel
  interfaces, files, registry and services. It is the most robust approach, because a correct implementation keeps
  working when the game is updated.
- **A Windows PC's identity where a game insists on one:** when a game refuses, degrades or misbehaves because of what
  the Mac really is, we present what a Windows PC would. Examples:
  - a GPU vendor and device id the game knows, and a driver version it accepts;
  - CPU feature flags and a Windows build number it accepts;
  - an environment without Wine markers.

  The disguise is the smallest one that works, set by a rule for that game (ADR-0006), and it's recorded in the rule's
  comment: what the game checks, and what we report instead.
- **Protection runs as on Windows:** anti-cheat and DRM must run and pass, as they do on a PC. They are not removed,
  stubbed or patched out. They run in the environment above. Reverse-engineering them to learn what they check is in
  scope (each fork's `REVERSE-ENGINEERING.md`).

**Where the line is:** the purpose is playing, never gaining an advantage.
- Nothing changes the game's rules, data or code in order to cheat.
- Nothing helps another player cheat.
- Nothing works against what the anti-cheat protects: fair play and the game's integrity. We change only what the
  game believes about the machine.
- Account, ownership and licence checks stay intact. You play games you own, on your own account.

**Evidence still applies (white paper §0):** a claim that a game "needs" a component (a driver such as
`eaanticheat.sys`, a service, a hardware id) is checked before work starts on it.

## Consequences
- **Hardware-identity rules are allowed.** These include the `wine_get_version` rename (2026-10-13), a rule that
  reports another GPU vendor, and per-game Windows build numbers.
- **Disguises are the narrowest that work, scoped per game.** One game's need doesn't change what every other game
  sees, unless the same need shows up generally.
- **Online play carries a risk the hub can't remove.** An anti-cheat may still flag a disguised environment. The owner
  accepts that risk for games he owns. The hub doesn't hide that a disguise is in use from the owner: `hub doctor`
  and the session log list the active rules.
- **Long-term items:** F1 24 under EAAC (roadmap 0022) and the Ubisoft packer fixups (roadmap 0028) are covered by
  this rule.
