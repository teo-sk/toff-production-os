# Bootstrap

Install Production OS templates into a Unity game repository.

## Usage

```bash
# From the Production OS repo
./bootstrap/bootstrap.sh --help

# Preview (no writes)
./bootstrap/bootstrap.sh --dry-run /absolute/path/to/game-repo

# Install missing files only (default)
./bootstrap/bootstrap.sh /absolute/path/to/game-repo

# Overwrite managed files
./bootstrap/bootstrap.sh --force /absolute/path/to/game-repo

# Regression tests (disposable fixtures only)
./bootstrap/tests/run-tests.sh
```

## Behavior

1. Accepts an explicit target path (canonicalized).  
2. Enforces **exact Git repository identity** when Git applies to the path.  
3. Detects Unity via `ProjectSettings/ProjectVersion.txt` (verified when present).  
4. Treats directory basename and discovered `.unity` files as **suggestions only** (`NEEDS_CONFIRMATION`).  
5. Skips existing files unless `--force`.  
6. Renders `AGENTS.md` with verified / inferred / unknown provenance; leaves TODOs for humans.  
7. Installs Cursor rules, selected docs templates, and `scripts/validate.sh`.  
8. Writes `docs/production-os-version.txt` with framework version.  
9. Prints a post-bootstrap report (verified vs inferred vs unknown).  

**Never** runs against the Production OS repo itself.  
**Never** installs Unity packages or edits gameplay code / scenes / assets / `ProjectSettings`.  
**Never** launches Unity, creates remotes, commits, pushes, or initializes Git.

## Safety guarantees

### Git root identity

- The target directory is resolved to a canonical absolute path.
- If `git rev-parse --show-toplevel` succeeds for that path, the toplevel **must equal** the canonical target exactly.
- Nested directories that merely live inside a parent Git repository are **rejected**.
- Standalone Unity repositories whose Git root is the target are accepted.
- Bootstrap does **not** run `git init`.

### Symlink policy (conservative)

- Destination paths must remain **physically inside** the canonical target root.
- Any **symlink component** in a managed destination path (intermediate directory or leaf file) is **rejected**.
- Bootstrap never follows a destination symlink to write outside the target.
- `--force` does **not** bypass these checks and will not overwrite through a symlink.
- Symlinked target paths themselves are refused; pass the real repository directory.

### Dry-run

- `--dry-run` prints the planned actions and report only.
- It performs **no writes** to the target (no files, directories, or marker updates).

### Existing-file protection

- Default mode **skips** existing managed files (including game-specific `AGENTS.md` and `.cursor/rules`).
- `--force` may overwrite those managed paths **only after** destination safety checks pass.
- `--force` cannot be used to escape the target via symlinks or path tricks.

### Verified vs inferred configuration

| Value | Provenance |
|---|---|
| Unity project / editor version from `ProjectSettings/ProjectVersion.txt` | **Verified** when the file is readable |
| Git toplevel == target | **Verified** when Git applies and matches |
| Game name from directory basename | **Inferred** — `NEEDS_CONFIRMATION`, not product identity |
| `.unity` files under `Assets/Scenes` | **Candidates only** — never assumed to be the main scene |
| Layout, namespaces, platforms, one-liner, architecture | **Unknown / TODO** until a human fills them |

The report lists verified, inferred, and unknown values explicitly. Weak heuristics never silently become authoritative gameplay or architecture claims.

## Known limitations

- **TOCTOU:** Safety checks run immediately before each write. A concurrent process could still replace a path component with a symlink between check and write. Run against trusted local directories; do not race the bootstrap.
- Physical containment uses `realpath` / `python3` canonicalization; exotic network filesystems may differ.
- Missing Unity metadata is reported honestly; templates may still be installed for docs/rules onboarding.
- No automatic upgrade / three-way merge for customized consumer files beyond re-running with careful `--force` review.

## After bootstrap

1. Confirm every `NEEDS_CONFIRMATION` / `TODO` in `AGENTS.md` and docs.  
2. Align doc filenames with any existing project convention.  
3. Configure `scripts/validate.config.sh` if needed.  
4. Human review before first commit.  
