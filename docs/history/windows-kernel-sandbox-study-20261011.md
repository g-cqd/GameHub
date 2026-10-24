# Feasibility: a sandboxed "virtual Windows kernel" on macOS for EA Javelin (EAAC) — 2026-10-11

Produced by a research agent (read-only shell; saved here by the orchestrator). Facts are cited; inferences are marked. Not independently re-verified by the orchestrator except the local measurements, which come from our Wine tree.

Machine: Apple M2 Pro, 16 GB, arm64, Darwin 27.2; free space: internal 56 GB, /Volumes/ExT2 38 GB at the time (local `sysctl`, `df`; ExT2 free space has changed since).

## 1. Verdict
| Path | Can be built? | Will EAAC run and be accepted? |
|---|---|---|
| User-space virtual NT kernel (extended Wine ntoskrnl/winedevice) | Yes, as a compatibility layer for generic drivers | Cannot be promised. Hardware attestation can't be provided genuinely, the x64 driver can't run as kernel code, EA hasn't opted in to Wine (sections 4–6) |
| Windows 11 Arm VM (Parallels/Fusion/UTM) | Yes, commodity | No today: no ARM64 Javelin driver has shipped, and EA titles refuse VMs (section 3) |

## 2. What a virtual NT kernel would have to provide (public architecture only)
A driver of this class is written against the documented WDK surface:
- object manager and handles
- I/O manager (DRIVER_OBJECT/DEVICE_OBJECT, IRPs)
- memory manager (MDLs, pool, cross-process memory)
- process/thread/image-load notify routines and object callbacks
- registry callbacks
- Filter Manager minifilters
- IRQL/DPC/APC semantics, ETW
- the kernel-mode code-signing policy

IRQL semantics are defined in terms of masking interrupts on the processor ("DISPATCH_LEVEL and APC_LEVEL interrupts are masked off") [MS-IRQL].
Since Windows 10 1607, "Windows will not load any new kernel-mode drivers which are not signed by the Dev Portal"; cross-signed drivers are still allowed when Secure Boot is off [MS-SIGN]. x64 Kernel Patch Protection bug-checks on modification of kernel code and structures [MS-KPP][MS-X64R].

**Can't be done outside ring 0 on macOS (inference from the docs above plus macOS's user/kernel split):**
- real interrupt masking and DPC/ISR timing
- IDT/GDT/MSR/CR access
- physical memory and DMA
- a Microsoft-measured Secure Boot chain, TPM attestation, and HVCI/VBS (VBS requires a hypervisor)
- visibility into non-Wine macOS processes

**Can be emulated:** these semantics only *within the Wine process world* (wineserver already owns processes, threads, handles and mappings). That makes it a compatibility layer, not a Windows kernel.

## 3. VM baseline (short)
- **Licensing.** Microsoft names Parallels Desktop 18, 19 and 20 as authorized solutions for running Arm versions of Windows 11 Pro and Enterprise; a unique license is required per instance; limitations include DirectX 12 issues and no VBS or nested virtualization [MS-MAC].
- **Graphics.** Parallels: DirectX up to 11.1 and OpenGL 4.3, and "Most anti-cheat software won't run in a virtual environment" [PD-KB]. VMware Fusion 13.5+: DirectX 11 on Apple silicon [BCM-KB][FUS135]. UTM: no 3D acceleration for Windows guests [UTM]. Apple's Virtualization.framework targets macOS and Linux guests [AVF].
- **Kernel drivers on Windows on Arm.** "Emulation only supports user mode code and doesn't support drivers" [MS-EMU]; kernel drivers must be built as native Arm64 [MS-FAQ]. EA says Javelin "will offer native ARM64 support" "in the near future" (10 Sep 2026; no date) [EA-2026].
- **VM policy.** BF6 requires Secure Boot, TPM 2.0, HVCI-capable and VBS-capable [EA-BF6]; EA says TPM is strictly enforced and HVCI/VBS not yet enforced [EA-S4]. EA lists "Virtual Machines and Emulation" among the threats Secure Boot helps it fight [EA-SB]. Players report "Unable to run in a Virtual Machine… (121)" [EAF-121]; Shadow PC and VK Play Cloud are refused [EAF-VM] (forum threads, not EA policy pages). Context: Epic's EAC states its client is not supported on VMs [EPIC-VM].
- **Expected frame rate (inference).** At or below Wine+DXMT for DX11 titles (Prism x64 emulation plus a paravirtual GPU); DX12-only titles fail.

## 4. Current starting point (measured locally, our Wine tree, Wine 11.0 base)

| Component | Size | Spec entries | Stub / semi-stub |
|---|---|---|---|
| dlls/ntoskrnl.exe (`ntoskrnl.c` 4,715, `pnp.c` 1,571, `sync.c` 1,452, `instr.c` 948 lines; 356 KB) | 1,710 entries | 743 `stub`, 950 implemented (161 aliases) | about 103 FIXME stub/semi-stub functions in C |
| dlls/hal | 198 lines | 92 | 71 |
| dlls/fltmgr.sys | 152 lines | 163 | 153 |
| programs/winedevice/device.c | 161 lines | — | — |
| server/device.c | 1,171 lines | — | — |

WineHQ's API page reports 1,708 exports with 949 implemented (56%), consistent with the local count [WINE-API]. Wine 11.18 (18 Sep 2026) added "More NTOSKRNL support for kernel drivers" [WINE-NEWS]; our tree predates it (last local ntoskrnl commit 2025-09-03).

**How Wine loads drivers today.** `services.exe` launches `winedevice.exe` for `SERVICE_KERNEL_DRIVER` (`programs/services/services.c:518,824-842`); ntoskrnl then loads the `.sys` with `LoadLibraryExW` in that user process (`dlls/ntoskrnl.exe/ntoskrnl.c:3940-4011`). `NtLoadDriver` in ntdll is a stub (`dlls/ntdll/unix/system.c:4646-4649`).

**Anti-cheat-class APIs today:**
- `ObRegisterCallbacks`: FIXME, returns success (`ntoskrnl.c:3152-3159`)
- `PsSetCreateProcessNotifyRoutineEx`, `PsSetCreateThreadNotifyRoutine`: stubs returning success (`:3299-3312`)
- `PsSetLoadImageNotifyRoutineEx`: semi-stub (`:3565`)
- `CmRegisterCallback`: `STATUS_NOT_IMPLEMENTED` (`:3743-3746`)
- `MmCopyVirtualMemory`: `STATUS_NOT_IMPLEMENTED` (`:4332-4340`)
- `KeStackAttachProcess`: stub (`:4620`); `KeInsertQueueDpc`: stub (`:2639`)
- `EtwRegisterClassicProvider`: FIXME, success (`:4665`); `MmMapIoSpace`: returns NULL (`:2940-2943`)
- `KeGetCurrentIrql`: stub returning 0 (`hal/hal.c:139-142`)

`instr.c` emulates a few privileged x86_64 instructions and KUSER_SHARED_DATA reads.

**Comparison.** ReactOS master (35c272d, 2026-10-11) has a 473-file, 9.48 MB `ntoskrnl/` and a 1,655-entry `ntoskrnl.spec` — about 27x Wine's ntoskrnl source volume. Published Windows 11 ntoskrnl export counts are about 3,161 [EXP].

## 5. Precedents and how x64 driver code would execute on Apple silicon
- **Captive NTFS:** ran Microsoft's ntfs.sys in Linux user space on ReactOS-derived code; hardware instructions must be trapped and emulated or ignored [CAPTIVE].
- **NDISwrapper:** implements the Windows kernel/NDIS APIs inside the Linux kernel; x86/x86-64 only; openSUSE calls it a "solution of last resort" [NDIS][SUSE]. **Longene:** NT kernel functionality inside the Linux kernel [LONGENE].
- **ReactOS ARM64:** experimental boot (May 2026); not native on Apple hardware [REG][ROS-X].
- **Rosetta:** does not translate kernel extensions or VM apps that virtualize x86_64 platforms [ROSETTA]; "macOS 27: Final release to support Rosetta" as a general tool, only a gaming subset continues [APPLE-NEWS]. Implication (inference): an x64 `.sys` could only run as user-mode code inside a Rosetta-translated winedevice process with privileged instructions emulated. Unverified: whether Rosetta delivers those faults recoverably. Long term the only robust route is a native ARM64 driver, which only EA can ship.

## 6. Sizing estimate (INFERENCE)
Scope: a minimal user-space NT kernel that loads one signed x64 driver of this class with correct semantics against Wine processes (notify routines and object callbacks wired to wineserver; cross-process memory; APC/DPC/IRQL emulation; a minifilter manager of ~150 stubs; registry callbacks, ETW, PnP gaps).
Basis: Wine's ~19 years of driver hosting reached 56% export coverage; ReactOS's kernel is ~27x larger.
**Estimate: 24–96 person-months** (2–4 kernel-experienced engineers over 12–24 months) plus ongoing tracking of driver updates. Excludes anything about EA accepting the environment — Secure Boot, TPM and HVCI cannot genuinely exist in user space.

## 7. Policy point
Epic and BattlEye support Wine/Proton only when each game's developer opts in [GOL-EAC]. EA's Javelin has no such opt-in; a March 2026 job listing says EA wants to "chart a path… such as Linux and Proton" [GOL-JOB]. Whether a non-Windows kernel environment is accepted is EA's decision. This study deliberately contains nothing on imitating genuine Windows or analysing the anti-cheat.
- Can be built honestly: better Wine ntoskrnl coverage for non-anti-cheat drivers (peripherals, copy-protection, filesystem filters), labelled "not Windows".
- Cannot be promised: EAAC/Javelin titles (BF1, BF2042, F1 24, BF6).

## 8. Experiment plan and decision tree
- **Step 0 (free, now):** monitor [EA-2026] for the ARM64 Javelin release and EA Help/news for any Proton/Wine opt-in.
- ARM64 Javelin shipped? **No:** stop (a VM cannot load the x64 driver [MS-EMU]). **Yes:** Parallels/VMware Fusion trial: Windows 11 Pro Arm + own license [MS-MAC], VM on the internal SSD, 8 GB guest / 8 GB host, 4–6 vCPU, EA account; launch one EAAC title once and record the message without trying to get past a refusal; if refused (likely [EAF-121]) the result is "unsupported by EA"; if it starts, compare frame rate with Wine+DXMT and watch HVCI/VBS enforcement [EA-S4].
- EA opts in Wine/Proton? **Yes:** integrate EA's user-mode client through Wine as was done for EAC/BattlEye. **No:** keep virtual-kernel work scoped to non-anti-cheat drivers.
- Ban risk: no public EA page found stating a VM launch leads to a ban; documented behaviour is a launch refusal [EAF-121]. Unverified.

## Not verified / conflicts
- help.ea.com anticheat page timed out; EA forum threads returned 403 (quotes from search excerpts).
- Parallels pages disagree (KB: DX11.1/GL 4.3; marketing: DX11/GL 4.1) [PD-KB].
- x87/FP behaviour under Prism was not researched.

## Sources
[MS-IRQL] https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/managing-hardware-priorities · [MS-SIGN] https://learn.microsoft.com/en-us/windows-hardware/drivers/install/kernel-mode-code-signing-policy--windows-vista-and-later- · [MS-KPP] https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc759759(v=ws.10) · [MS-X64R] https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/driver-x64-restrictions · [MS-MAC] https://support.microsoft.com/en-us/windows/experience/platform-variants/options-for-using-windows-11-with-mac-computers-with-apple-m1-m2-and-m3-chips · [MS-EMU] https://learn.microsoft.com/en-us/windows/arm/apps-on-arm-x86-emulation · [MS-FAQ] https://learn.microsoft.com/en-us/windows/arm/faq · [PD-KB] https://kb.parallels.com/en/122485 · [BCM-KB] https://knowledge.broadcom.com/external/article/315609/features-of-windows-11-vm-on-mac-with-in.html · [FUS135] https://docs.vmware.com/en/VMware-Fusion/13.5/rn/vmware-fusion-135-release-notes/index.html · [UTM] https://docs.getutm.app/updates/v4.1/ · [AVF] developer.apple.com/documentation/virtualization · [ROSETTA] https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment · [APPLE-NEWS] https://developer.apple.com/news/?id=w5ngl9k2 · [EA-2026] https://www.ea.com/news/ea-javelin-anticheat-2026-update · [EA-BF6] https://www.ea.com/games/battlefield/battlefield-6/news/get-ready-for-battlefield-6 · [EA-S4] https://www.ea.com/games/battlefield/battlefield-6/news/battlefield-6-anticheat-update-season-4 · [EA-SB] https://www.ea.com/games/battlefield/battlefield-6/news/secure-boot-information · [EAF-121] https://forums.ea.com/discussions/battlefield-6-technical-issues-en/unable-to-run-in-a-virtual-machine-please-exit-the-vm-and-try-again-121/12789008 · [EAF-VM] https://forums.ea.com/discussions/ea-forums-general-discussion-en/why-does-ea%E2%80%99s-anti-cheat-block-virtual-machines-like-shadow-pc/11892243 · [EPIC-VM] https://www.epicgames.com/help/c-32735058/c-37477814/a21516107 · [GOL-EAC] https://www.gamingonlinux.com/2021/09/epic-games-announce-full-easy-anti-cheat-for-linux-including-wine-a-proton/ · [GOL-JOB] https://www.gamingonlinux.com/2026/03/ea-javelin-anticheat-job-listing-mentions-future-support-for-linux-and-proton/ · [WINE-API] https://source.winehq.org/WineAPI/ntoskrnl.html · [WINE-NEWS] https://www.winehq.org/news/ · [EXP] https://gist.github.com/kkent030315/cc119d0036c4ea42d06ddc423f5760a2 · [CAPTIVE] http://www.jankratochvil.net/project/captive/doc/Architecture.pm · [NDIS] https://en.wikipedia.org/wiki/NDISwrapper · [SUSE] https://en.opensuse.org/SDB:Ndiswrapper · [LONGENE] https://en.wikipedia.org/wiki/Longene · [REG] https://www.theregister.com/os-platforms/2026/05/28/reactos-brings-its-windows-nt-tribute-act-to-arm64/5247768 · [ROS-X] https://x.com/reactos/status/2059616705811247353 · Local: /Volumes/ExT2/GameHub/src/wine.
