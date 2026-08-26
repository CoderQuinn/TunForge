## Summary

<!-- What changed and why -->

## Test plan

- [ ] `./Scripts/run-tests.sh unit` passes locally (or wait for **Unit Tests**)
- [ ] `./Scripts/run-tests.sh regression` passes locally when lifecycle/accept behavior changes
- [ ] **CI** and **Lint** checks pass
- [ ] Contract changes include XCTest coverage per [docs/TESTING.md](../docs/TESTING.md)
- [ ] No new Swift Testing (`import Testing`) in this package
- [ ] Lifecycle tests that `stop` the stack also `start` again in `tearDown`

## Docs

- [ ] Updated `docs/ARCHITECTURE.md` / review notes if contracts changed
