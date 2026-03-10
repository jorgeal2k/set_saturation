# Project context

## Project type
This repository is an Android Magisk module project.

## Main goals
- Develop and maintain portable Android shell scripts.
- Keep compatibility with Magisk-style module structure.
- Favor reliability during boot and installation phases.

## Shell target
- Primary shell target: /system/bin/sh
- Do not assume bash is available.
- Avoid bashisms such as:
  - arrays
  - [[ ]]
  - source
  - process substitution
  - bash-only string expansions

## Environment assumptions
- Host OS: Windows
- Main development terminal: WSL Ubuntu
- Target runtime: Android shell environment
- Commands must be clearly separated between:
  - Windows host
  - WSL/Linux host
  - Android device shell

## Coding rules
- Prefer portable POSIX-style shell.
- Keep functions small and reusable.
- Quote variables unless unquoted expansion is required.
- Add concise English comments only when they improve maintainability.
- Do not rewrite unrelated sections of files.
- Preserve existing module structure unless explicitly asked to refactor it.

## Tooling
- Use shellcheck-compatible shell style where possible.
- Use shfmt-friendly formatting.
- Preserve LF line endings.

## Project structure
- `service.sh`: late boot logic
- `post-fs-data.sh`: early boot logic
- `customize.sh`: install-time logic
- `common/`: shared helper functions