# Copilot Instructions for Yuruyomi

## Project Overview
Yuruyomi is a manga reader plugin for KOReader, forked from rakuyomi. It's a **hybrid architecture** combining:
- **Rust backend** (`backend/`) - HTTP server with WASM-based manga sources
- **Lua frontend** (`frontend/yuruyomi.koplugin/`) - KOReader plugin UI
- **WASM manga sources** (`sources/`) - Pluggable scrapers for manga sites

## Key Architecture Patterns

### Domain Model (Critical IDs)
All entities use hierarchical composite IDs:
```rust
SourceId -> MangaId { source_id, manga_id } -> ChapterId { manga_id, chapter_id }
```
- Always construct via `from_strings()` or `new()` methods
- URLs encode these as `/mangas/{source_id}/{manga_id}/chapters/{chapter_id}`

### Backend Structure
- **`shared/`** - Core domain logic, database, WASM runtime
- **`server/`** - HTTP server with Axum routes
- **`wasm_*`** - WASM support crates for source plugins
- **Use cases pattern**: All business logic in `shared/src/usecases/`

### Frontend-Backend Communication
- Lua frontend calls HTTP API via `Backend.lua`
- All responses follow `{ type: 'SUCCESS', body: T } | { type: 'ERROR', message: string }`
- Uses Unix Domain Sockets for local communication

### WASM Source System
Sources are compiled WASM modules implementing Aidoku-compatible API:
- `create_manga()` - Parse manga metadata
- `create_chapter()` - Parse chapter listings
- `create_page()` - Parse page/image URLs
- WASM imports provide HTTP, HTML parsing, JSON utilities

## Development Workflows

### Build & Run Commands
```bash
# Backend only
./tools/dev-backend.sh [--debug] [--tcp]

# Frontend only (requires backend running)
./tools/dev-frontend.sh [--no-server-check]

# Full application
./tools/dev-both.sh
```

### Database Operations
- SQLite with migrations in `backend/shared/migrations/`
- Always use SQLX for queries: `sqlx::query_as!()`
- Prepare queries: `./tools/prepare-sqlx-queries.sh`

### Testing
- **E2E tests**: Python in `e2e-tests/` using KOReader automation
- **Unit tests**: Standard Rust tests, Lua test stubs via `testing.lua`
- Run: `xvfb-run ./ci/run-e2e-tests.sh`

## Critical Development Patterns

### Error Handling
- Rust: Use `anyhow::Result` for fallible operations
- Lua: Check response types, show `ErrorDialog` for failures
- HTTP layer: Custom `AppError` with proper status codes

### Database Patterns
- **Write-through caching**: Always `upsert_cached_manga_information()` after source fetches
- **Async streaming**: Use `futures::stream` for concurrent source operations
- **Cancellation**: Pass `CancellationToken` through async chains

### UI State Management
Lua components follow callback-passing pattern:
```lua
ChapterListing:fetchAndShow(manga, onReturnCallback)
-- Stores callback in self.paths stack for navigation
```

### Source Development
When adding WASM source support:
1. Implement Aidoku API functions
2. Register WASM imports in `wasm_imports/`
3. Handle rate limiting via `set_rate_limit()` calls
4. Parse HTML via provided `html` module imports

### File Organization
- HTTP routes in `{domain}/routes.rs` (e.g., `manga/routes.rs`)
- Use cases in `shared/src/usecases/{operation}.rs`
- Models split: domain models in `shared/src/model.rs`, HTTP DTOs in `server/src/model.rs`

## Common Gotchas
- **URL encoding**: Always use `util.urlEncode()` for manga/chapter IDs in Lua
- **WASM memory**: Use `descriptor_from_i32()` helpers for WASM value handles
- **Async contexts**: Can't hold `source_collection` across await points - clone sources first
- **SQLite strict mode**: All tables use `STRICT` - ensure proper type handling
- **Cross-platform builds**: Uses Nix for reproducible multi-target compilation

## Testing Integration Points
- Use `Testing:emitEvent()` for E2E test coordination
- Background downloads via job system in `server/src/job/`
- Chapter storage abstraction for download location management

## KOReader Plugin UI Development

### Widget Hierarchy & Core Components
KOReader uses a widget-based UI system. All components inherit from base `Widget`:

**Container Widgets**:
- `InputContainer` - Handles touch events and key presses via `registerTouchZones()`
- `FrameContainer` - Adds borders, padding, background to content
- `CenterContainer`, `BottomContainer`, etc. - Layout positioning
- `ScrollableContainer` - Enables scrolling for content overflow

**Interactive Widgets**:
- `Button` - Basic clickable button with text/icon and callback
- `TouchMenu` - Hierarchical menu system (used extensively in Yuruyomi)
- `ListView` - Paginated list with `page_update_cb` for navigation
- `ConfirmBox` - Modal dialogs with Cancel/OK actions
- `InputDialog` - Text input dialogs with validation

### Touch Event Handling Pattern
```lua
local InputContainer = require("ui/widget/container/inputcontainer")
local widget = InputContainer:new{}
widget:registerTouchZones({
    {
        id = "tap_action",
        ges = "tap",
        screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 0.5 },
        handler = function(ges)
            -- Handle tap on top half of screen
            return true  -- Event consumed
        end
    }
})
```

### UI Manager Integration
- All widgets shown via `UIManager:show(widget)`
- Use `UIManager:close(widget)` to dismiss
- Modal dialogs block interaction until closed
- `covers_fullscreen = true` for full-screen components

### Widget Composition Examples
```lua
-- Typical Yuruyomi dialog structure
local dialog = FrameContainer:new{
    background = Blitbuffer.COLOR_WHITE,
    bordersize = Size.border.window,
    CenterContainer:new{
        VerticalGroup:new{
            TextWidget:new{ text = "Title" },
            ListView:new{ items = manga_list },
            Button:new{
                text = "Close",
                callback = function() UIManager:close(dialog) end
            }
        }
    }
}
```

### Menu Integration Pattern (Critical for Plugins)
```lua
-- Plugin entry point registration
function YourPlugin:addToMainMenu(menu_items)
    menu_items.your_plugin = {
        text = _("Your Plugin"),
        callback = function() self:showMainView() end
    }
end
```

### Navigation State Management
Yuruyomi uses callback stacking pattern:
```lua
-- Store return path in self.paths
self.paths = { { callback = onReturnCallback } }
-- Navigate forward, pass new callback
NextView:show(data, function() UIManager:show(self) end)
```

### Widget Lifecycle & Screen Management
- Widgets auto-calculate dimensions unless specified
- Use `Screen:scaleBySize()` for DPI-aware sizing
- Handle screen rotation with `updateTouchZonesOnScreenResize()`
- Memory management: close widgets to prevent leaks

## KOReader UI Module Reference

### Core UI Framework
- `ui.uimanager` - Central widget manager for showing/closing widgets with detailed refresh control:
  - `show(widget, refreshtype, refreshregion, x, y, refreshdither)` - Display widget with refresh options
  - `close(widget, refreshtype, refreshregion, refreshdither, refreshfunc)` - Close widget with cleanup
  - Refresh types: `"full"` (complete refresh), `"partial"` (efficient partial), `"ui"` (UI changes), `"fast"` (rapid updates), `"a2"` (A2 mode for e-ink)
  - `setDirty(widget, refreshtype, refreshregion, refreshdither, refreshfunc)` - Mark for refresh without show/close
  - `scheduleIn(seconds, action)` - Delayed execution, returns handle for `unschedule(handle)`
  - `nextTick(action)` - Execute on next event loop tick
  - `sendEvent(event, widget)` - Direct event dispatch to specific widget
  - `broadcastEvent(event)` - Send event to all widgets in hierarchy
- `ui.event` - Event messaging system through widget tree:
  - `Event:new(name, arguments)` - Create events with structured data
  - Event propagation through widget hierarchy with "on"..Event.name handler naming
  - Handlers return true to stop propagation, false/nil to continue bubbling
- `ui.geometry` - 2D geometry utilities for layout calculations
- `ui.size` - Standardized sizes for consistent widget dimensions
- `ui.font` - Font management and text rendering
- `ui.trapper` - Linear job interaction without explicit callbacks

### Widget Containers
- `ui.widget.container.framecontainer` - Bordered content with background
- `ui.widget.container.inputcontainer` - Touch/key event handling
- `ui.widget.container.centercontainer` - Center-aligned content
- `ui.widget.container.scrollablecontainer` - Scrollable content (set as `cropping_widget`)
- `ui.widget.container.alphacontainer` - Opacity-controlled content (0..1)
- Layout containers: `bottomcontainer`, `topcontainer`, `leftcontainer`, `rightcontainer`

### Interactive Widgets
- `ui.widget.button` - Text/icon buttons with callbacks
- `ui.widget.touchmenu` - Hierarchical menu system for complex navigation structures
- `ui.widget.listview` - Paginated lists with `page_update_cb`
- `ui.widget.confirmbox` - Cancel/OK modal dialogs
- `ui.widget.inputdialog` - Text input with validation
- `ui.widget.multiconfirmbox` - Three-option dialogs (cancel/choice1/choice2)
- `ui.widget.toggleswitch` - State toggle buttons
- `ui.widget.radiobuttonwidget` - Single selection from list
- `ui.widget.checkbutton` - Checkbox with ✓/□ states

### Display Widgets
- `ui.widget.textwidget` - Single-line text display
- `ui.widget.textboxwidget` - Multi-line text with wrapping
- `ui.widget.textviewer` - Scrollable text display
- `ui.widget.imagewidget` - Image display from file/memory
- `ui.widget.progresswidget` - Progress bar display
- `ui.widget.notification` - Top-screen notifications
- `ui.widget.infomessage` - Informational message display

### Layout Widgets
- `ui.widget.horizontalgroup` - Side-by-side layout
- `ui.widget.verticalgroup` - Stacked layout
- `ui.widget.overlapgroup` - Layered content
- `ui.widget.linewidget` - Line separators

### Specialized Widgets
- `ui.widget.progressbardialog` - Progress dialog with title/subtitle
- `ui.widget.keyvaluepage` - Multi-page key-value display
- `ui.widget.numberpickerwidget` - Numeric value selection
- `ui.widget.datetimewidget` - Date/time selection
- `ui.widget.imageviewer` - Image viewer with manipulation
- `ui.downloadmgr` - Directory chooser for downloads

### Plugin Development
- `ui.plugin.background_task_plugin` - Background task with enable/disable switch
- `ui.plugin.switch_plugin` - Simple enable/disable plugin base
- `ui.menusorter` - Menu construction from items and order
- `ui.presets` - Unified preset management interface

### Internationalization & Input
- `gettext` - Translation system (use `_("text")` for translatable strings)
- `ui.bidi` - Bidirectional text and UI mirroring
- Input methods: `generic_ime`, `ja_keyboard`, `ko_KR_helper`, `zh_keyboard`

### Utilities
- `util` - Miscellaneous frontend helpers with comprehensive text/HTML/URL processing:
  - `urlEncode(text)` / `urlDecode(text)` - URL percent-encoding for safe parameter passing
  - `stripPunctuation(text)`, `trim(s)`, `cleanupSelectedText(text)` - Text cleaning utilities
  - `tableEquals(o1, o2)`, `tableDeepCopy(o)`, `arrayAppend(t1, t2)` - Table manipulation
  - `htmlToPlainText(text)`, `htmlEscape(text)`, `htmlEntitiesToUtf8(string)` - HTML processing
  - `fileExists(path)`, `directoryExists(path)`, `makePath(path)` - File system utilities
  - `getSafeFilename(str, path, limit)` - Cross-platform filename sanitization
  - `isCJKChar(c)`, `hasCJKChar(str)`, `splitToWords(text)` - Unicode/text analysis
- `ui.rendertext` - Text rendering utilities
- `ui.renderimage` - Image rendering utilities
- `ui.hook_container` - Event listener registration system

## AI Assistant Guidelines

### Documentation & API References
- **For additional KOReader UI details**: If you need more specific API documentation beyond what's covered here, ask the user to fetch details from the KOReader plugins UI guide at https://koreader.rocks/doc/index.html
- **Architecture questions**: Refer to this document first, then ask for clarification on specific patterns if needed

### Learning & Mentoring Approach
**Primary Goal**: This project serves as a learning environment for Rust and Lua development. Act as a senior developer providing pair programming guidance.

**Rust Mentoring**:
- Explain ownership, borrowing, and lifetime concepts when relevant to code changes
- Highlight idiomatic Rust patterns: `Result<T, E>` error handling, `Option<T>` for nullable values, iterator chains
- Demonstrate async/await patterns, especially with `tokio` and `futures` crates used in the backend
- Point out memory safety benefits and zero-cost abstractions when applicable
- Suggest performance optimizations using Rust's type system (e.g., `&str` vs `String`, avoiding unnecessary clones)
- Explain macro usage, especially for SQLX queries and WASM bindings

**Lua Mentoring**:
- Focus on KOReader-specific patterns: widget composition, event handling, callback management
- Teach Lua table manipulation idioms and metatable usage where relevant
- Explain closure patterns and proper scope management in callback-heavy UI code
- Demonstrate error handling patterns specific to the KOReader environment
- Show how to write maintainable UI code with proper separation of concerns

**Best Practices**:
- Always explain *why* a particular approach is recommended, not just *what* to do
- Provide alternative implementations when educational value exists
- Suggest refactoring opportunities that improve code clarity or performance
- Encourage testing strategies appropriate for each language and component
- Share debugging techniques specific to Rust (using `dbg!`, `#[cfg(debug_assertions)]`) and Lua (KOReader logging patterns)
