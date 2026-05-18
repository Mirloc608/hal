## Summary

Describe the purpose of this PR in one or two sentences.

## Checklist before opening PR

Please run these locally and confirm in the checklist below:

- [ ] `make -n` (Makefile dry-run) completes without errors
- [ ] `TAG=test HAL_ROOT=$(pwd) make -n render-all` completes without errors
- [ ] `shellcheck scripts/*.sh` shows no new warnings (or explain why)
- [ ] `shfmt -d scripts/*.sh` shows no formatting diffs (or run `shfmt -w` to fix)
- [ ] If you added tests, `bats` tests pass locally

## What changed

Explain the changes and any important implementation notes.

## Testing

Describe how this was tested locally (commands used, environment).

## Notes

Add any additional notes for reviewers (breaking changes, migration steps, etc.).
