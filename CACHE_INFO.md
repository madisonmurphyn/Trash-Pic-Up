# Photo Analysis Cache Information

## Cache Location

The analysis cache is stored at:
- **macOS**: `~/Library/Application Support/TrashPicUp/photo_analysis_cache.json`
- **iOS**: App's Application Support directory (sandboxed)

## How It Works

1. **First Launch**: 
   - No cache exists, so all photos are analyzed
   - Results are saved to cache as they're analyzed
   - Cache is saved every 50 photos and at the end of analysis

2. **Subsequent Launches**:
   - Cache is loaded **synchronously** before analysis starts
   - Only photos that aren't cached (or have been modified) are analyzed
   - Cached results are loaded instantly

3. **Cache Invalidation**:
   - Photos are re-analyzed if:
     - They've been modified (modification date changed)
     - They've been created after cache was made
     - Cache entry is older than 30 days

## Verifying Cache is Working

When you run the app, check the Xcode console for these messages:

- `✅ Loaded X cached analysis results from: [path]` - Cache loaded successfully
- `📊 Cache status: X entries at [path]` - Shows cache stats before analysis
- `📈 Analysis: X cached, Y need analysis out of Z total` - Shows how many photos use cache
- `💾 Saved X analysis results to cache` - Cache saved successfully

## Testing Without Re-analysis

To test without restarting analysis:

1. **Run the app once** and let it complete analysis
2. **Check console** for "💾 Saved X analysis results" message
3. **Stop the app** (don't force quit - let it save)
4. **Rebuild and run** - you should see:
   - `✅ Loaded X cached analysis results`
   - `📈 Analysis: X cached, 0 need analysis` (or very few)
   - Analysis should complete almost instantly

## Manual Cache Management

If you need to clear the cache (force re-analysis):

1. Delete the cache file manually:
   ```bash
   rm ~/Library/Application\ Support/TrashPicUp/photo_analysis_cache.json
   ```

2. Or add a "Clear Cache" button in the app (future feature)

## Troubleshooting

**Cache not persisting?**
- Check console for error messages
- Verify the cache file exists at the path shown in console
- Check file permissions

**Cache not loading?**
- Look for "❌ Error loading cache" in console
- The cache file might be corrupted - delete it and let it rebuild

**Still analyzing everything?**
- Check console output to see cache stats
- Verify cache file exists and has entries
- Photo IDs might have changed (unlikely but possible)

## Space & Time Optimizations

- **Compact JSON**: Cache is stored as minified JSON (no pretty-printing) to reduce file size.
- **Max cache size**: Cache is capped at 20,000 entries. When full, the 1,000 oldest entries (by `cachedDate`) are evicted before adding new ones. This keeps disk usage bounded on large libraries.
- **Screenshot IDs**: Fetched once per load (during photo fetch) and reused for all analysis, avoiding repeated album crawls.
- **Analysis thumbnails**: Blur/duplicate analysis uses 96×96 thumbnails instead of 150×150, reducing I/O and memory.
- **Duplicate groups**: Cleared from memory after each analysis run to free RAM.

## Cache File Format

The cache is a JSON file with this structure:
```json
{
  "photo-id-1": {
    "analysis": {
      "isDuplicate": false,
      "isScreenshot": true,
      "isBlurry": false,
      "blurScore": 0.85,
      "duplicateGroup": null
    },
    "photoModificationDate": "2026-01-23T12:00:00Z",
    "photoCreationDate": "2026-01-22T10:00:00Z",
    "cachedDate": "2026-01-23T12:30:00Z"
  }
}
```
