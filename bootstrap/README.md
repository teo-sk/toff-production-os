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
```

## Behavior

1. Accepts an explicit target path.  
2. Detects Git and Unity (`ProjectSettings/ProjectVersion.txt`).  
3. Guesses game name / primary scene when possible.  
4. Skips existing files unless `--force`.  
5. Renders `AGENTS.md` with discovered values; leaves remaining TODOs for humans.  
6. Installs Cursor rules, selected docs templates, and `scripts/validate.sh`.  
7. Writes `docs/production-os-version.txt` with framework version.  
8. Prints a post-bootstrap report.  

**Never** runs against the Production OS repo itself.  
**Never** installs Unity packages or edits gameplay code.  
**Never** commits or pushes.

## After bootstrap

1. Fill TODOs in `AGENTS.md` and architecture rules.  
2. Align doc filenames with any existing project convention.  
3. Configure `scripts/validate.config.sh` if needed.  
4. Human review before first commit.  
