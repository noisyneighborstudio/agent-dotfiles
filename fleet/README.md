# Fleet

Spread CI across the Macs on the tailnet without a scheduler. GitHub already queues jobs and hands each one to an idle runner whose labels match. The fleet decides only which runners are open.

- `fleet.toml` lists every host: its state, planned slots and what else runs there.
- A gate runs on each active host every minute. While the host has headroom, its runners carry the `fleet-open` label. When load, memory or disk crosses a threshold, the gate removes the label. A runner without the label gets no new jobs; a job already running is never touched, so closing a host cannot cancel work.
- The gate reopens only after the 5-minute load settles below `open_load`, so a host does not flap.

## Commands

```bash
fleet/fleet status          # every host: gate, load, memory, disk, runners, busy, planned slots
fleet/fleet install <host>  # copy fleet + fleet.toml to the host and start its gate
fleet/fleet drain <host>    # close the host; running jobs finish
fleet/fleet open <host>     # hand the host back to the gate
fleet/fleet gate --dry-run  # on a host: show what the gate would do
```

`hands-off` hosts are never contacted, not even by `status`. `excluded` hosts appear in status only. Commands need `uv`; the gate also needs `gh` signed in as an account with admin on every repo whose runners the host carries.

The gate's log is `~/Library/Logs/fleet-gate.log` on each host. `status` shows `stale` when a gate has not reported for three minutes.

## Rolling out

Order matters: a job that asks for `fleet-open` waits forever if no runner carries it.

1. `fleet install <host>` on every active host. Check `fleet status` shows each gate `open` or `closed` with a reason.
2. Change each workflow's `runs-on` to ask for the label, e.g. `runs-on: [self-hosted, macOS, fleet-open]`.
3. Bring each host's runner count to its `slots`.

Registering runners at the organisation instead of per repository lets any host serve any repo. That needs a token with org admin (`gh auth refresh -h github.com -s admin:org`) and is not automated yet.
