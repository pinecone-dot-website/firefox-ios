# JIT on the phone through a debugger (research, 2026-11-06)

Option 2 from the M4 discussion: get SpiderMonkey's JIT running in the dev-signed build without
BrowserEngineKit. Nothing here is built yet.

## How iOS allows it

- A dev-signed app has `get-task-allow`, so a debugger may attach. While a debugger is attached
  the process is `CS_DEBUGGED`, and iOS lets it have executable memory it wrote itself.
- **Older chips (no TXM):** attach once, detach, and JIT works for the rest of that launch.
- **TXM devices** (Trusted Execution Monitor; Eric's iPhone 17 Pro has it): a page only becomes
  executable after the *debugger* writes to it. The app asks for this through a breakpoint
  protocol that StikDebug's `universal.js` script answers:
  - `brk #0xf00d` with `x16 = 1` ("prepare region"), `x0 = address` (0 = let the debugger
    allocate), `x1 = size`. The debugger touches every 16 KB page and returns the executable
    address in `x0`. Validate the result; an unanswered breakpoint leaves junk in `x0`.
  - `x16 = 0` detaches.
  - The returned mapping is execute-only. The app makes a writable alias of the same pages
    (`vm_remap` + `vm_protect`) and writes code through the alias.
  - A `brk` with no debugger attached kills the process, so only issue it after confirming
    `CS_DEBUGGED`.
- Sources disagree on two points that need an on-device test: whether passing an address the app
  mapped itself works (Play!'s PR says only the NULL/debugger-allocated path works), and whether
  pages stay executable after detach (Play! never detaches).
- Sources: StikJIT `INTEGRATION.md`; Play--CodeGen PR #34 (tested on iPhone 15 Pro Max,
  iOS 26.x); StikDebug release notes mention iOS 27 fixes.

## Who plays the debugger

- **StikDebug on the phone.** Fennec opens `stikdebug://enable-jit?bundle-id=…&pid=…&script-name=universal.js`
  at launch. Needs a pairing file made once from the Mac, Developer Mode, StikDebug's local VPN
  and a mounted Developer Disk Image (lasts until reboot). Works away from the Mac.
- **The Mac (lldb).** Launch from the Mac with lldb attached and an lldb script that answers the
  same breakpoints. No source covers this; only works while tethered or on the same network.
- Licenses of StikDebug/StikJIT and the sample allocators (shadPS4, Play!) weren't checked. Write
  our own; Reynard (GPL) is reference only.

## What Gecko would need

- SpiderMonkey's iOS executable memory (`js/src/jit/ProcessExecutableMemory.*`) assumes
  BrowserEngineKit: `MAP_JIT` plus `be_memory_inline_jit_restrict_*` to flip a page between
  writable and executable. Under TXM that flip isn't available.
- The new path: reserve one large region at startup through the debugger, keep an RW alias, and
  make every code write (initial copy and later in-place patching of jumps and IC stubs) go
  through the alias. SpiderMonkey writes and patches code in place in many places, so this is the
  big part of the work.
- Turn JIT on only when the region was granted (`javascript.options.main_process_disable_jit`
  false), otherwise stay on the interpreter.

## Suggested first step

A tiny standalone test app on the phone: request a region through the protocol, write a `ret`
through an RW alias, call it. Try it with lldb from the Mac and with StikDebug. That settles the
open questions before touching SpiderMonkey.
