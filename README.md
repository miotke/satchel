# Satchel

A unified bag window for World of Warcraft: Forever. The backpack and your four bags show as one grid, with the reagent bag and keyring as optional sections. The bank gets a window of its own.

## Install

Copy or symlink this folder into `World of Warcraft/_forever_/Interface/AddOns/Satchel`.

## Use

Open your bags as usual (B, the bag bar, vendors). The bank window opens when you talk to a banker. Drag a title bar to move a window. The gear button holds the section options and category management.

### Categories

Make your own categories, like "Tanking", and put items in them. A category is a section of the backpack and bank, at the top until you move it. It shows only while one of its items is there, and everything else stays in the unified grid.

- **Alt+right-click** an item to pick its category, make a new one, or take it out.
- **Drag** an item onto a category's header to add it, or onto the Bags header to take it out.
- Items belong to a category by item ID, so an item goes back to its category whenever it returns to your bags, for example after you unequip it.
- **Right-click** any header to move that section up or down. Categories, Bags, Reagents and Keyring can go in any order, and the backpack and bank each keep their own.
- Rename, move and delete categories in the gear menu under Categories, too.

### Pinned slots

Drag an item to the spot you want, then Alt+right-click it and choose **Pin to this slot**. It shows there from then on, with a pin mark, even after Sort or new loot moves it in your bags.

- A pin is a position in its section counted from the top left, so bigger bags only add slots after it.
- If a section shrinks below the pin, the item shows in its last slot. If two pins want the same spot, the item that comes first in your bags gets it, and the other takes the next free one.
- Only the first stack of a pinned item is pinned. The backpack and bank have their own pins.

### Commands

| Command | Does |
| --- | --- |
| `/satchel` | Toggle the backpack |
| `/satchel cols <6-30>` | Backpack slots per row (default 10) |
| `/satchel bankcols <6-30>` | Bank slots per row (default 14) |
| `/satchel scale <0.5-2>` | Window scale |
| `/satchel reagent` | Show or hide the reagent bag (shown by default) |
| `/satchel keyring` | Show or hide the keyring (hidden by default; the keyring button still shows it) |
| `/satchel new <name>` | Make a category |
| `/satchel perf` | Toggle a small window with memory, growth per second and redraw timings |
| `/satchel reset` | Move the windows back to their default spots |

## Develop

`luajit tests/smoke.lua .` runs the add-on headless against stubbed WoW APIs. It catches logic errors, not how anything looks in the game.

## Not yet

Bank bag sockets (buy a tab or swap a bank bag in Blizzard's bank for now), Masque skins.
