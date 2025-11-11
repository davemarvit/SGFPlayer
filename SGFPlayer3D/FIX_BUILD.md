# Fix for "Multiple commands produce" Build Error

## What was the problem?

Xcode's File System Synchronized Groups was including ALL files in the SGFPlayer3D folder in the bundle, including:
- Files we deleted (cached in Xcode)
- Backup files (*.backup)
- Documentation files (*.md)
- Old test resources (*.obj, *.dae, *.exr)

This caused each file to be added to the bundle TWICE, resulting in the "Multiple commands produce" error.

## What was fixed?

Added explicit exclusion rules to the Xcode project file (PBXFileSystemSynchronizedBuildFileExceptionSet) to tell Xcode to SKIP these files:
- `old_resources/` folder
- `Info.plist` (auto-generated)
- `Integration/INTEGRATION_SUMMARY.md`
- `ViewModels/PhysicsViewModel.swift.backup`

## Steps to complete the fix:

1. **Close Xcode completely** (Cmd+Q)

2. **Pull the latest changes:**
   ```bash
   git pull origin claude/availability-check-011CV19YJ1AUXrURYAfFRUXK
   ```

3. **Run the deep clean script:**
   ```bash
   cd SGFPlayer3D
   ./deep_clean_xcode.sh
   ```

4. **Open Xcode**

5. **Clean Build Folder** (Cmd+Shift+K)

6. **Build** (Cmd+B)

## Expected result:

- Build should succeed
- Copy Bundle Resources should show a reasonable number of items (not 169)
- No more "Multiple commands produce" errors

## If you still see errors:

Let me know which files are still causing "Multiple commands produce" errors and I'll add them to the exclusion list.
