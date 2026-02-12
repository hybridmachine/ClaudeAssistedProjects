# GameOfLife3D.NET UI Modernization Plan

## Current State
The app uses ImGui.NET with default-ish styling. The control panel has collapsing headers, basic buttons, and minimal theming. The timeline bar uses text labels for transport. The status bar is a simple text overlay. Everything works but looks utilitarian.

## Design Philosophy
- **Dark theme** with a cohesive accent color (teal/cyan matching the 3D visualization)
- **Visual hierarchy** through spacing, grouping, and color weight
- **Desktop best practices**: consistent spacing, clear affordances, hover feedback, logical grouping
- **Subtle polish**: rounded corners, separator lines, icon-decorated headers, hover effects

## Implementation Steps

### 1. Create a dedicated `Theme.cs` for centralized style/color management
- Define a complete color palette: background, surface, border, text, accent, accent-hover, accent-active, muted text, success/warning colors
- Apply a comprehensive ImGui style: rounding, padding, borders, item spacing, scrollbar styling, tab styling
- Replace scattered style overrides in App.cs and individual UI files with theme application

### 2. Modernize the Control Panel (`ImGuiUI.cs`)
- **Section headers**: Replace plain `CollapsingHeader` with custom-drawn headers using accent-colored indicator bars and Unicode section icons
- **Button groups**: Style compute buttons as a cohesive button bar with consistent sizing
- **Pattern buttons**: Render as pill-shaped buttons with consistent width
- **Sliders & inputs**: Apply custom styling for better contrast and visual weight
- **Visual grouping**: Use `ImGui.BeginChild` regions with subtle border/background for each logical group
- **Spacing**: Increase spacing between sections, tighter spacing within groups
- **Labels**: Right-align labels for cleaner form layout where appropriate
- **Color pickers**: Keep ImGui's built-in color picker (it's already good)

### 3. Modernize the Timeline Bar (`TimelineBar.cs`)
- **Transport icons**: Replace text labels (`|<`, `<`, `Play`, etc.) with Unicode symbols: `⏮`, `⏪`, `▶`/`⏸`, `⏩`, `⏭`, `⟳`
- **Styled progress track**: Custom-draw the generation scrubber with a filled track showing progress
- **Visual separation**: Top border line as visual separator from viewport
- **Speed indicator**: Styled badge/pill for current speed

### 4. Modernize the Status Bar (`StatusBar.cs`)
- **Segmented display**: Draw individual info segments with subtle separators
- **Label + value** pattern: muted label color, bright value color
- **Icon prefixes**: Unicode icons for each status segment (generation, rule, cells, FPS)

### 5. Update `App.cs` to use the Theme system
- Remove inline style overrides
- Call `Theme.Apply()` after ImGui initialization
- Keep DPI scaling logic intact

### 6. Add a `UIHelpers.cs` utility class
- Custom-drawn section headers with accent bar
- Styled button helpers (accent button, icon button, button bar)
- Tooltip helper with consistent styling
- Separator with label

## Files to Create
- `src/GameOfLife3D.NET/UI/Theme.cs` - Color palette and style application
- `src/GameOfLife3D.NET/UI/UIHelpers.cs` - Reusable custom-drawn UI components

## Files to Modify
- `src/GameOfLife3D.NET/UI/ImGuiUI.cs` - Redesigned control panel
- `src/GameOfLife3D.NET/UI/TimelineBar.cs` - Modernized timeline
- `src/GameOfLife3D.NET/UI/StatusBar.cs` - Segmented status bar
- `src/GameOfLife3D.NET/App.cs` - Theme integration

## Key Constraints
- Must stay within ImGui.NET capabilities (no XAML, no external UI frameworks)
- Must preserve all existing functionality
- Must maintain DPI scaling support
- Must keep cross-platform compatibility (Windows + Linux)
- No external font files or image assets (use Unicode and ImGui drawing primitives)
