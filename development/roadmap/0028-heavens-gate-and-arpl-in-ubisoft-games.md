---
status: not-started
blocked-by: []
date: 2026-10-24
---

# 0028: Confirm the Heaven's-gate fixup and ARPL in the 32-bit Ubisoft games

- **Wine 73516bb:** rewrites the Ubisoft packer's selector-0x33 far jumps when a rule asks. The rule is
  `section=.ubx2 => gate_selector_fixup=true`.
- **x87sidecar dbda79a:** translates ARPL even in blocks that go to stock Rosetta.

Neither has been confirmed in a game.

## Done when
A 32-bit Ubisoft game with the `.ubx2` section starts on hub-2, and its log shows the fixup applied.
