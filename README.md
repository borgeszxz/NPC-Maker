# NPC Maker

Find an avatar, customize it, give it a brain.

A Roblox Studio plugin that builds a complete, working NPC from a player
avatar, marketplace items, or a raw asset/bundle id - without leaving Studio.

Generated NPCs are standalone: they keep working after the plugin is
uninstalled.

---

## 1. Architecture

Three layers, one direction of dependency: `UI` calls `Modules`, `Modules`
call `Utils`, and nothing calls back up.

The rule that shaped the design: **no UI file is allowed to reason about
asset types.** All catalog knowledge lives in `MarketplaceItemAdapter`, so
adding support for a new item kind is one table entry, not a hunt through
pages.

```
              catalog result / player id / asset id
                              |
                    MarketplaceItemAdapter          <- what is this, can we apply it
                              |
                    DescriptionBuilder              <- base look + layered items
                              |
                    HumanoidDescription
                              |
                       NPCBuilder                   <- model, config, script, undo
                              |
                        Workspace.NPCs
```

### Decisions worth calling out

**The base description is never mutated.** `DescriptionBuilder` keeps a
pristine base plus an ordered item list, and `build()` clones the base and
applies the items. Removing an item is exact rather than an attempt to
reverse an edit, so the preview can never drift from what gets created.

**The slow call happens outside the undo recording.**
`CreateHumanoidModelFromDescriptionAsync` is a web request. `NPCBuilder`
finishes it *before* `ChangeHistoryService:TryBeginRecording`, so the
recording wraps only synchronous DataModel writes - the folder, the model,
the Config, the controller - which is what makes the whole thing one Ctrl+Z.

**Slot rule is stated, not arbitrary.** One item per AssetType. Adding a
second Hair replaces the first, and the card says *"Replaces Knight Hair"*
before you click. Layered clothing keeps an `Order` value, which is what
`HumanoidDescription:SetAccessories` needs to stack it correctly.

**Unsupported means unsupported.** If a catalog item is not something a
HumanoidDescription can carry, the card is disabled with a reason. Nothing
is guessed at, and no NPC is broken to make a feature look complete.

**One owner for "settings become an NPC".** A single local `buildOptions`
inside `ConfigPanel` is the only place that turns the current state into
`NPCBuilder.Options`. The Create page, the Create button and the keyboard
shortcuts all route through it, so the summary shown on the Create page
cannot drift from what actually gets built.

### The window

**Floating, and dockable.** `Window` hosts the UI in a DockWidgetPluginGui
that opens floating. Studio supplies the outer title bar and, with it, the
docking cross: drag the window to any edge and it snaps into a pane.
Everything inside is the plugin's own - branded header, pills, panels - so
the only Studio control in the title bar is the one Studio draws itself.

**The palette is not Studio's.** `Enum.StudioStyleGuideColor` makes every
plugin look like a stock property pane. `UI/Theme` defines its own tokens -
a blue accent, dark and light palettes, hover and disabled states derived
from the base colour - and borrows exactly one thing from Studio: whether
the user is in light or dark mode, so the window sits comfortably beside the
editor without imitating it.

**Responsive by layout, never by scaling.** An earlier version drew the UI
at a fixed 1240 x 820 and shrank it with a UIScale. That left dead space
around the edges and made the text tiny the moment the window was resized.
Now every page decides between two layouts from the width it is given:

- **Columns** - holders positioned by fraction, each panel fills its holder
  and scrolls internally, the page itself does not scroll.
- **Stacked** - a UIListLayout is parented in, holders flow top to bottom at
  full width, each panel grows to fit its content, and the page scrolls.

The threshold is per page, `MIN_PANEL_WIDTH` (320) times the number of
panels: the builder needs room for three, the Create page only two, so
Create stays in columns longer. Panels support both through `setMode`, and
in stacked mode they give up their own scrolling entirely - a scroller
inside a scroller is what makes stacked layouts feel broken. The header
compacts below 560px: shorter bar, smaller wordmark, no tagline.

**Layout is polled, not signalled.** `AbsoluteSize` change signals fire
before the new size has propagated through the nested frames, so a listener
reads the previous width and the layout ends up one resize behind - which is
exactly the bug that made the window stay stacked at full width. Both
`MainWidget` and `Window` compare a single cached number once a frame
instead. It costs nothing and is always correct.

### Module responsibilities

| File | Owns |
|---|---|
| `Utils/Maid` | Cleanup: connections, instances, callbacks, in one `destroy()` |
| `Utils/NameUtils` | Sanitising, defaults, `Name_2` / `Name_3` uniqueness |
| `Utils/ValidationUtils` | Number parsing (rejects NaN, inf, blanks, out-of-range), id/URL parsing |
| `Modules/Settings` | Persisted preferences as one JSON blob, plus the presets |
| `Modules/AvatarService` | The `Players` avatar APIs, each pcall-wrapped, each returning a human-readable error |
| `Modules/MarketplaceBrowser` | `CatalogSearchParams`, search, pagination, session cache |
| `Modules/MarketplaceItemAdapter` | Catalog result -> supported? which slot? how to apply? |
| `Modules/DescriptionBuilder` | The avatar being assembled; the only source of truth |
| `Modules/BehaviorTemplates` | The five runtime controller scripts |
| `Modules/AnimationController` | Server-side replacement for the Animate LocalScript |
| `Modules/SpawnManager` | Cursor / origin / selection placement |
| `Modules/NPCBuilder` | Model, humanoid config, attributes, Config, controller, crowds, undo |
| `UI/Theme` | Colour tokens and the type scale; borrows only light/dark from Studio |
| `UI/Components` | Panels, buttons, checkboxes, dropdowns, pills, tiles, fields, status lines |
| `UI/Window` | The DockWidgetPluginGui host, branded header, compact mode |
| `UI/MainWidget` | Pill navigation, the three pages, the responsive layout |
| `UI/AvatarPanel` | Step 1: Player / Marketplace / Asset ID sources |
| `UI/MarketplacePanel` | The in-plugin catalog browser, as a paged tile grid |
| `UI/PreviewPanel` | Step 2: live ViewportFrame preview and the current item list |
| `UI/ConfigPanel` | Step 3: name, rig, stats, behavior, spawn, Create NPC. Owns `buildOptions` |
| `UI/NPCListPanel` | NPC page: every NPC in the place, select / delete |
| `UI/CreatePanel` | Create page: identity, presets, advanced options, summary, crowd |

---

## 2. File tree

```
NPCMaker
├── Main                         Script
├── Utils
│   ├── Maid                     ModuleScript
│   ├── NameUtils                ModuleScript
│   └── ValidationUtils          ModuleScript
├── Modules
│   ├── Settings                 ModuleScript
│   ├── AvatarService            ModuleScript
│   ├── MarketplaceBrowser       ModuleScript
│   ├── MarketplaceItemAdapter   ModuleScript
│   ├── DescriptionBuilder       ModuleScript
│   ├── BehaviorTemplates        ModuleScript
│   ├── AnimationController      ModuleScript
│   ├── SpawnManager             ModuleScript
│   └── NPCBuilder               ModuleScript
└── UI
    ├── Theme                    ModuleScript
    ├── Components               ModuleScript
    ├── Window                   ModuleScript
    ├── MarketplacePanel         ModuleScript
    ├── AvatarPanel              ModuleScript
    ├── PreviewPanel             ModuleScript
    ├── ConfigPanel              ModuleScript
    ├── NPCListPanel             ModuleScript
    ├── CreatePanel              ModuleScript
    └── MainWidget               ModuleScript
```

Repository layout maps one-to-one: `src/Main.server.luau` becomes the `Main`
Script, and each `src/<Folder>/*.luau` becomes a ModuleScript inside a Folder
of that name.

---

## 3. API review

Every API below was executed against a live Roblox Studio in Edit mode
before the code was written, not recalled from memory. Notes are what the
probe actually returned.

| API | Status |
|---|---|
| `AvatarEditorService:SearchCatalogAsync` | Works in Edit mode. Returns `CatalogPages`. |
| `CatalogSearchParams` | All 14 fields present: SearchKeyword, MinPrice, MaxPrice, SortType, SortAggregation, CategoryFilter, SalesTypeFilter, BundleTypes, AssetTypes, CreatorName, CreatorType, CreatorId, IncludeOffSale, Limit. |
| `CatalogPages:GetCurrentPage` / `.IsFinished` / `:AdvanceToNextPageAsync` | All work. Pagination verified 30 -> 60 results. |
| `AvatarEditorService:GetItemDetails(id, Enum.AvatarItemType)` | Works for both Asset and Bundle. |
| `Players:GetUserIdFromNameAsync` | Works. Invalid name raises "Unknown user", which is caught and shown as *User not found.* |
| `Players:GetNameFromUserIdAsync` | Works. Used when the input is numeric. |
| `Players:GetHumanoidDescriptionFromUserIdAsync` | Works. |
| `Players:GetHumanoidDescriptionFromOutfitIdAsync` | Works. Both the Async and non-Async spellings exist; the Async one is used with a fallback. |
| `Players:CreateHumanoidModelFromDescriptionAsync` | Works in Edit for R15 (19 children) and R6 (10 children). |
| `HumanoidDescription:GetAccessories(true)` / `:SetAccessories(list, true)` | Work. Entries carry AssetId, AccessoryType, IsLayered, Position, Rotation, Scale, plus Order for layered items. |
| `ChangeHistoryService:TryBeginRecording` / `:FinishRecording` | Present. `Enum.FinishRecordingOperation.Commit` and `.Cancel` exist. Modern API, no `SetWaypoint`. |
| `plugin:GetMouse()` (PluginMouse) | The supported way to read the viewport pointer from a plugin. |
| `rbxthumb://type=Asset&id=...` and `type=BundleThumbnail` | Accepted by `ImageLabel.Image`. The only supported way for a plugin to show catalog art. |
| `Enum.Font.BuilderSans` / `Medium` / `Bold` | All present. The whole UI uses this family. |

**Two things the specification assumed that are not true**, found by probing:

1. `Enum.CatalogCategoryFilter` does **not** contain item kinds. It has only
   `None, Featured, Collectibles, CommunityCreations, Premium, Recommended`.
   Item kinds (Hair, Hats, Shirts, Body Parts, ...) are expressed through
   `AssetTypes` and `BundleTypes`, which is what the Category dropdown maps
   to.
2. The catalog returns `AssetType` as a **string** (`"HairAccessory"`), not
   an EnumItem or a number. The adapter resolves it to
   `Enum.AvatarAssetType` by name and reports anything that fails to resolve
   as unsupported.

**Deprecated APIs avoided:** `Model:SetPrimaryPartCFrame` (uses `PivotTo`),
`ChangeHistoryService:SetWaypoint` (uses the recording pair),
`Players:GetCharacterAppearanceAsync` (uses the HumanoidDescription APIs),
`Humanoid:LoadAnimation` (uses `Animator:LoadAnimation`).

**Script source:** assigned directly to the newly created `Script` instance.
`ScriptEditorService:UpdateSourceAsync` applies to documents open in the
script editor; a freshly created, never-opened Script is written through its
`Source` property, which is the supported path for plugins.

---

## 4. Three hard parts

### NPCs animate

`Players:CreateHumanoidModelFromDescriptionAsync` returns a rig whose
`Animate` script is a **LocalScript**. LocalScripts do not run in Workspace
for anything that is not a player character, so an NPC built straight from
that model never plays a single animation - it slides around stiff.

`AnimationController` keeps the valuable half of what Roblox generated - the
Animation value objects, whose ids already reflect the avatar's equipped
animation package - and reparents them under a small server `Script` that
the plugin owns. The NPC keeps the familiar `Animate` structure, and it
actually runs.

Roblox's own 972-line Animate source is not reused: it references
`Players.LocalPlayer`, which is nil on the server, and it changes between
releases.

### Feet land on the ground

Character models built from a description have no `PrimaryPart`, so their
pivot sits at the bounding box centre rather than at the feet. Pivoting
straight onto a surface buries the NPC to the waist. `SpawnManager` returns
the point the feet should touch and `NPCBuilder` measures the model's own
bounding box to work out the offset. Verified: feet land 0.05 studs above
the target surface.

### Keyboard shortcuts

`PluginMouse` only reports a position while the pointer is over the
viewport. Clicking **Create NPC** in the panel necessarily moves the pointer
off the viewport, so "At Cursor" used the last stale position - which is why
NPCs landed somewhere unhelpful.

The plugin registers three actions under
**File > Advanced > Customize Shortcuts**:

- **Create NPC at cursor** - always spawns at the pointer, whatever the
  configured spawn mode is. Aim in the viewport, press the key.
- **Create NPC** - same as the button, honouring the configured spawn mode.
- **Toggle NPC Maker window** - show or hide the window.

Roblox does not allow a plugin to assign a default key, so the binding is
yours to choose.

---

## 5. The preview

`PreviewPanel` renders the avatar in a `ViewportFrame` with a `WorldModel`
and its own `Camera`. Arrows or a mouse drag spin it.

Building the preview means calling
`CreateHumanoidModelFromDescriptionAsync`, which is a web request - one per
accessory would be wasteful and slow. So changes are coalesced: a change
schedules a rebuild 0.35s out, later changes replace the pending one, and a
generation counter makes a late reply from a superseded request discard its
own model instead of showing a stale avatar.

Three facts about ViewportFrame WorldModels shape the preview, all verified
against a live Studio:

- **Nothing falls.** There is no gravity, so the character is *not*
  anchored. Anchoring was an earlier bug: an anchored rig cannot be
  repositioned by its Humanoid, so avatars with non-default body scales ended
  up with limbs in the wrong places.
- **Humanoids animate.** The rig's own idle clip is loaded onto its Animator,
  so the preview breathes instead of standing in a T-pose.
- **The camera frames the body, not the bounding box.** A single oversized
  accessory would otherwise push the camera so far back the character became
  a dot. Rotation eases toward its target every frame rather than snapping.

Scripts are stripped from the preview model: it is scenery.

Two honest limits: `ViewportFrame` cannot render a Sky, so the backdrop is a
themed gradient rather than a pretend skybox; and the plugin ships no
external image assets, so icons and the wordmark glyph are drawn from UI
frames and text rather than imported art.

---

## 6. Type

One family, Builder Sans (Roblox's own UI face), in three weights. Title 26
Bold, subtitle 14, panel headings 18 Bold, pills 15 Bold, labels 13 Medium,
inputs 14, buttons 14 Bold, the Create NPC button 16 Bold, card names 13
Medium, small text 11-12. All of it lives in `Theme.Font` / `Theme.Size`.

---

## 7. Install

### Prebuilt

Copy `build/NPCMaker.rbxm` into your local plugins folder:

- Windows: `%LOCALAPPDATA%\Roblox\Plugins`
- macOS: `~/Documents/Roblox/Plugins`

Then **restart Roblox Studio**. Studio only loads a newly added plugin file
on startup.

### Rojo

```sh
rojo build --output build/NPCMaker.rbxm
```

This is how the shipped file is produced. `.rbxm` is Roblox's binary model
format: the instance tree is stored in LZ4-compressed chunks, so the file is
about a quarter the size of the XML equivalent and the source is not
readable in a text editor.

That is compactness, not protection. Anyone who drags the file into Studio
sees every script exactly as written - Roblox has no bytecode-only format
for plugins, and a plugin is by definition its scripts. The only way source
stops travelling with the file is publishing the plugin to the Creator
Store, where Roblox serves it as an asset id instead.

### Without Rojo

```sh
python build/build_plugin.py --install
```

Packs `src/` into `build/NPCMaker.rbxmx` (XML) and copies it to the plugins
folder. A dependency-free fallback; the XML is human-readable.

### Testing as a local plugin from inside Studio

If you would rather not restart: build the tree by hand in ServerStorage
(one Folder named `NPCMaker`, containing the `Main` Script and the three
Folders), then right-click it and choose **Save as Local Plugin**. Studio
loads it immediately.

---

## 8. Using it

Click **NPC Maker** in the toolbar. Three pages, chosen with the pills under
the header.

### Avatar - the builder

Three panels side by side (stacked when the window is narrow).

**1. Choose Avatar** - pick where the look comes from:

- **Player** - type `builderman` or a UserId, press *Load*. The avatar
  becomes the base immediately.
- **Marketplace** - type `medieval knight`, pick a Category, press *Search*,
  then the round **+** on the tiles you want. Results are paged nine at a
  time: `<` / `>` walk the pages and only call the catalog again when you
  run off the end of what is loaded. The **×** inside the search box clears
  the results; the button beside *Search* opens the advanced filters (sort,
  price range, off-sale items, and *Hide items that cannot be applied*,
  which is on by default so emotes and animation packs do not fill the grid
  with dead tiles).
- **Asset ID** - paste `123456789`, a bundle id, or a `roblox.com/catalog/…`
  URL. Auto Detect works out which it is.

**2. Preview** - the live 3D result, with the list of marketplace items
underneath. Remove any of them with the `×`. *Clear Items*, *Reset* and
*Refresh* sit below it, then **Use This Avatar**.

**3. Configure NPC** - name, rig (R15 / R6), Health, WalkSpeed, JumpPower,
Behavior, Spawn Position, and two options (*Add Config*, *Add Attributes*).
Then the green **Create NPC**.

Behaviors: `None`, `Idle`, `Wander`, `Follow Player`, `Guard Area`, `Enemy`.

### NPC - what you have already built

Every NPC in the place, found by the `NPC` attribute rather than by folder,
so ones you moved out of `Workspace.NPCs` still show. Per row: *Select*,
*Delete*. At the top: *Refresh*, *Select All*, *Delete All*. Deletes are one
undo step.

### Create - identity, presets and bulk

Left: **NPC Type** and **Faction** (written to the NPC as attributes), the
four presets (Friendly / Wanderer / Guard / Enemy - they change
configuration only, never the avatar), and the advanced options (*Put NPCs
inside Workspace.NPCs*, *Add behavior controller script*).

Right: a summary of exactly what the next Create will produce, the
**Create NPC** and **Create at Cursor** buttons, and **Create Crowd** -
N copies of the current avatar in a grid, `spacing` studs apart. One web
call builds the first; the rest are clones. One undo step for the whole
crowd.

The gear in the title bar jumps straight here.

### The result

```
Workspace
└── NPCs
    └── CastleGuard                 NPC=true, NPCType, Faction, Behavior,
        ├── Humanoid                SourceType, OriginalUserId
        ├── HumanoidRootPart
        ├── character parts + accessories
        ├── Animate                 server Script, plays the avatar's own idle
        ├── Config                  DetectionRange=50, GuardRadius=30
        └── NPCController           standalone runtime script
```

`Config` is a `Configuration` instance rather than a plain `Folder` - same
attribute behaviour, but it is the class Roblox provides for exactly this.

Ctrl+Z removes the whole thing in one step.

---

## 9. Known limitations

- **Catalog items that are not wearable** (Gear, animations, emotes) are shown with a disabled button and a reason. They cannot be applied to a HumanoidDescription.
- **Bundles** are applied through their `UserOutfit` entry, which resolves to a full HumanoidDescription and therefore replaces the whole base look. A bundle without an outfit reports that its look cannot be applied rather than guessing from its individual body-part assets.
- **Thumbnails** come from `rbxthumb://` content URIs. If one fails to resolve the tile still shows the name and price.
- **At Cursor** uses the last known viewport pointer position. If the mouse has not been over the viewport, it falls back to the origin and says so. The keyboard shortcut exists for exactly this reason.
- **No pathfinding.** The behaviors use `Humanoid:MoveTo`, which is honest about what it does: NPCs walk in straight lines and will get stuck on complex geometry. Adding `PathfindingService` properly means path caching and failure handling, and doing it badly is worse than not doing it.
- **Advanced catalog filters** (CreatorName, SalesTypeFilter, SortAggregation) are not exposed. The plumbing already accepts them - `MarketplaceBrowser.buildParams` assigns any field defensively - so surfacing them is UI work, not new logic.
