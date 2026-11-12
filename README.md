# Satchel

A unified bag window for World of Warcraft: Forever. The backpack and your four bags show as one grid, with the reagent bag and keyring as optional sections. The bank gets a window of its own.

## Install

Install it with an add-on manager that reads GitHub releases, or download the zip from [Releases](https://github.com/miotke/satchel/releases) and unzip it.

## Use

Open your bags as usual (B, the bag bar, vendors). The bank window opens when you talk to a banker. Drag a title bar to move a window. The gear button holds the section options and category management.

### Categories

Make your own categories, like "Tanking", and put items in them. A category is a section of the backpack and bank, at the top until you move it. It shows only while one of its items is there, and everything else stays in the unified grid.

- **Alt+right-click** an item to pick its category, make a new one, or take it out.
- **Drag** an item onto a category's header to add it, or onto the Bags header to take it out.
- Items belong to a category by item ID, so an item goes back to its category whenever it returns to your bags, for example after you unequip it.
- **Quest Items** is a built-in section that gathers quest items on its own and always sits at the bottom. A category you put an item in wins over it. Turn it off in the gear menu or with `/satchel quest`.
- **Right-click** any header to move that section up or down. Categories, Bags, Reagents and Keyring can go in any order, and the backpack and bank each keep their own.
- Rename, move and delete categories in the gear menu under Categories, too.
- Drop an item onto one in a category and the two swap categories as well as places. Turn this off in the gear menu with **Swapped items swap categories**.

### Pinned slots

Drag an item to the spot you want, then Alt+right-click it and choose **Pin to this slot**. It shows there from then on, with a pin mark, even after Sort or new loot moves it in your bags.

- A pin is a position in its section counted from the top left, so bigger bags only add slots after it.
- If a section shrinks below the pin, the item shows in its last slot. If two pins want the same spot, the item that comes first in your bags gets it, and the other takes the next free one.
- Only the first stack of a pinned item is pinned. The backpack and bank have their own pins.

### Bank tabs

Below the bank's slots is a row of bank tabs. Each tab after the first holds one bag.

- **Drop a bag** on an empty tab, or click it while holding a bag, to add the bag's slots to your bank. **Drag** a bag off a tab to take it out, or drop another on it to swap.
- The **plus** buys the next tab, through Blizzard's own purchase dialog. Hover it for the price.

### Your bank, anywhere

Each time you visit a banker, Satchel saves a copy of your bank for that character. Away from the bank, open it with the bag button next to Sort, or `/satchel bank`. It's read-only: hover for tooltips, shift-click to link, and search to find an item. The footer shows how old the copy is.

### Masque

With [Masque](https://www.curseforge.com/wow/addons/masque) installed, pick a skin for Satchel's Backpack and Bank groups in Masque's options.

### Commands

| Command | Does |
| --- | --- |
| `/satchel` | Toggle the backpack |
| `/satchel cols <6-30>` | Backpack slots per row (default 10) |
| `/satchel bankcols <6-30>` | Bank slots per row (default 14) |
| `/satchel scale <0.5-2>` | Window scale |
| `/satchel reagent` | Show or hide the reagent bag (shown by default) |
| `/satchel quest` | Turn the Quest Items section on or off (on by default) |
| `/satchel keyring` | Show or hide the keyring (hidden by default; the keyring button still shows it) |
| `/satchel bank` | Show the saved copy of your bank |
| `/satchel new <name>` | Make a category |
| `/satchel perf` | Toggle a small window with memory, growth per second and redraw timings |
| `/satchel reset` | Move the windows back to their default spots |
