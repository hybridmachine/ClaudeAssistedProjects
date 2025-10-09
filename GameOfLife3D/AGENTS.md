# Repository Guidelines

## Project Structure & Module Organization
- Source: `src/` TypeScript modules (e.g., `Renderer3D.ts`, `GameEngine.ts`). One class/module per file.
- Build output: `dist/` compiled JavaScript (`tsc` target).
- App shell: `index.html`, `styles.css` at repo root.
- Config: `tsconfig.json`, `package.json`.
- Utilities: `deploy.sh` / `deploy.bat` for static hosting. No secrets; runs client‑side only.

## Build, Test, and Development Commands
- `npm run build` — Compile TypeScript to `dist/`.
- `npm run watch` — Compile on change (fast feedback).
- `npm run serve` — Launch local static server on `http://localhost:8080/`.
- `npm run dev` — Build once, then serve.
- `npm run clean` — Remove `dist/`.

## Coding Style & Naming Conventions
- Language: TypeScript. Prefer explicit types; avoid `any`.
- Indentation: 2 spaces; LF line endings.
- Files/Classes: PascalCase (`Renderer3D.ts`).
- Functions/vars: camelCase; constants: UPPER_SNAKE_CASE.
- Imports: use relative paths within `src/`; keep public API via clear module boundaries.
- Three.js: favor `InstancedMesh`, object pooling, and minimal per‑frame allocations.

## Testing Guidelines
- No unit test framework is configured yet. For now:
  - Manual smoke test: `npm run dev`, verify load, camera controls, generation stepping, and FPS stability with 100 generations.
  - Add reproducible scenarios (pattern, grid size, generation range) in PR description.
- If introducing tests, place them under `tests/` and add an npm script; document the setup in `README.md`.

## Commit & Pull Request Guidelines
- Commits: imperative, concise subject (≤72 chars), include rationale in body when relevant.
- Prefer focused commits per concern (e.g., “Renderer: switch to InstancedMesh for cells”).
- PRs must include:
  - Purpose and user impact.
  - Screenshots/GIFs for UX changes, and performance notes (grid size, gen count, FPS).
  - Clear reproduction steps for reviewers.

## Agent‑Specific Notes
- Keep changes minimal and aligned with existing patterns; avoid adding heavy deps without discussion.
- Update `README.md` and scripts when adding commands or configuration.
- Respect file scope: changes in `src/` must compile via `npm run build` and not break `index.html` load path assumptions.
