
# Inkscape Patch Changelog

Documentation of additional patches applied when building the
Inkscape RPM package for AlmaLinux 10.

All patch files in this directory are automatically applied
in alphabetical order by `scripts/prepare-sources.sh`.

## 0001 – Guard GtkRecentManager in Headless Mode

- **Patch file:** `0001-guard-gtk-recent-manager-in-headless.patch`
- **Date:** 2026-11-07
- **Affected version:** Inkscape 1.4.4
- **Affected file:** `src/inkscape-application.cpp`
- **Status:** Backport of an upstream fix

### Problem

When running Inkscape in headless mode, for example when
exporting an SVG file to PNG via the command line,
Inkscape attempted to access `Gtk::RecentManager` even
though the GTK graphical interface had not been initialized.

This caused the following warning:

```text
Failed to wrap object of type 'GtkRecentManager'.
Hint: this error is commonly caused by failing to call a library init() function.
```

### Root Cause

In `InkscapeApplication::document_open()`,
`Gtk::RecentManager::get_default()` was called regardless
of whether Inkscape was running with or without a graphical
interface.

### Solution

Access to `Gtk::RecentManager::get_default()` is now protected
by an additional `_with_gui` check:

```cpp
if (_with_gui) {
    if (auto recentmanager = Gtk::RecentManager::get_default()) {
        // Existing recent-file handling
    }
}
```

Recent-file management is now only performed when running
in GUI mode.

### Goals

- Prevent the `GtkRecentManager` warning in headless mode.
- Ensure reliable command-line exports without unnecessary GTK access.
- Preserve existing behavior of the graphical interface.

### Upstream Reference

- Inkscape commit: `Don't access GtkRecentManager when running headless`
- Implementation: Adapted backport for Inkscape 1.4.4.

### Test Status

- [x] Patch successfully applied using `git apply`.
- [x] Source archive created with the patch applied.
- [x] RPM build completed successfully.
- [x] Headless export tested on AlmaLinux 10.
- [x] Absence of the warning confirmed.

---

## Additional Patches

Future patches will be documented here, including their
patch number, creation date, affected Inkscape version,
root cause, solution, and test status.
