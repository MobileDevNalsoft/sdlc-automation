---
name: react-ship
description: Use to build, tag, push, and deploy a react-bootstrap-scaffolded project's Docker image to a target host, with a post-deploy smoke check and a recorded previous-SHA for rollback. Use only after react-verify has reported GATE-PASS and sdlc-review has reported SHIP. Refuses to run until the container/build behaviors its Dockerfile depends on are human-confirmed at least once.
---

# react-ship

**Verb: release.**

## STOP CONDITIONS — read before invoking `scripts/ship.sh`

This skill's Dockerfile (from `react-sdlc:react-bootstrap`) and this skill's own `scripts/ship.sh` are written against container/build behaviors that are documented as generally true for the *class* of base images and tools involved, but have not been confirmed by actually running them against **your specific** chosen images/tools. Each is a named, checkable condition — not a vague warning. `ship.sh` literally refuses to execute (checks `$REACT_SHIP_STOP_CONDITIONS_CONFIRMED`) until a human sets that variable, and it must not be set until every condition below has actually been checked at least once against a real build.

| # | Condition | ASSUMPTION being made | How to confirm it |
|---|---|---|---|
| 1 | Your chosen nginx (or equivalent) base image executes `/docker-entrypoint.d/*.sh` on container start | It behaves like the standard `docker-library/nginx` image's documented entrypoint. Not every nginx-based image implements this convention — confirm for the specific image/tag you actually picked. | `docker run --rm <your-image>:<tag> sh -c 'cat /docker-entrypoint.sh'` and read it, or run a container with a test script under `/docker-entrypoint.d/` that just `echo`s a marker and check `docker logs` for it. |
| 2 | `npm run build -- --base=<path>` forwards `--base=<path>` through npm's script runner to the underlying `vite build`, overriding `vite.config.ts`'s `base` setting | npm's documented `--` arg-forwarding behavior and Vite's documented `--base` CLI flag combine correctly on THIS project's actual `package.json` build script. Each is individually documented; not confirmed together against your repo by actually running it. | Run it locally, inspect `dist/index.html`'s asset `<script src="...">` paths — do they carry the overridden base, or the config's original value? |
| 3 | A Dockerfile `ARG` expands inside a `COPY` **destination** path (`COPY --from=builder /app/dist /usr/share/nginx/html${BASE_PATH}`), not just a source path | Documented Docker behavior, but a less commonly exercised case than ARG-in-source. | `docker build` the template, then `docker run --rm <image> ls /usr/share/nginx/html/` and confirm the expanded subfolder exists rather than a literal `${BASE_PATH}`-named directory or a build error. |
| 4 | The specific base-image tag you pinned is still current and pullable | Tags on minimal/rolling base images are periodically retired. | `docker pull <your-image>:<your-tag>` — if it 404s, re-pin to whatever the current equivalent tag is everywhere this Dockerfile/SKILL.md cites it. |
| 5 | The entrypoint script's write into a `--chown`'d directory succeeds when running as the image's actual non-root UID | `chown` at build time is sufficient for a runtime write by that same user. | After condition 1 is confirmed runnable, check that the generated auth-header include file actually contains the expected directive after container start (`docker exec <container> cat <path-to-generated-conf>`), not still the empty placeholder. |

If any of the five turns out false, do not "fix it and ship anyway" in the same pass — the Dockerfile/nginx design in `react-bootstrap` may need to change shape (e.g. condition 1 failing means the auth-header injection needs a different trigger point entirely, not just a tweaked path). Report which condition failed and stop.

## What `scripts/ship.sh` does once conditions are confirmed

A generic build/push/deploy/smoke-check sequence, parameterized entirely by environment variables the adopting project sets (see the script's own header comment for the full list — image name/registry, deploy host, SSH key, host port, base path, smoke-check URL). It does not hardcode any project's specific registry account, host, or path — every one of those is a variable the adopting project supplies.

1. **Two image tags, not one.** Tags both `$SHIP_IMAGE:<git-sha>` AND `$SHIP_IMAGE:latest`, and deploys the SHA tag specifically — so "what's running right now" is never ambiguous the way a moving `:latest` tag is.
2. **`--build-arg BASE_PATH`** passed to `docker build` — the parameterized way to deploy the same image to a different subpath per environment, instead of mutating a tracked config file's `base:` literal per deploy and reverting it afterward (see react-bootstrap/SKILL.md's `BASE_PATH` section for why the mutate-and-revert approach is worth avoiding).
3. **Previous-SHA recording.** Before the old container is stopped, its `deployed-sha` label (set by this same script on every prior run) is read and written to a local rollback-reference file, plus printed as a ready-to-paste rollback command.
4. **Post-deploy smoke check.** If a smoke-check URL is configured, a `curl` against the deployed URL — a non-200 fails the script and prints the rollback command instead of silently reporting success. If none is configured, the script says so explicitly rather than silently skipping it.

## Rollback

```bash
docker run -d --name <container> --restart unless-stopped \
  -p <host-port>:<container-port> --label deployed-sha=<sha> \
  <registry>/<image>:<sha>
```

using the SHA printed by `ship.sh` (or read from the local rollback-reference file it wrote). This is a manual step, not automatic — an automatic rollback triggered by a failed smoke check has its own failure modes (what if the OLD image no longer exists locally or in the registry?) that this skill does not try to solve.

## Cross-references

- `react-sdlc:react-bootstrap` owns the Dockerfile/nginx templates this skill builds and runs — the STOP CONDITIONS above are about that skill's output, checked here because shipping is where they'd actually bite.
- `react-sdlc:react-verify` must report `GATE-PASS`, and `sdlc-core`'s `sdlc-review` agent must report `SHIP`, before this skill runs at all — this skill does not re-run either check itself.
- `sdlc-core:evidence-contract` — every STOP CONDITION row above is an `ASSUMPTION:` by definition (that's the entire reason this skill has a refusal gate); don't let a future edit to this file quietly drop the `ASSUMPTION:` framing once someone thinks they "obviously" know the answer.
