-- Modules loaded here will not be cleared and reloaded by the local harness.
-- Keeping these preloaded preserves cross-file setup while still resetting
-- non-helper modules between files.
require('test.functional.testnvim')()
