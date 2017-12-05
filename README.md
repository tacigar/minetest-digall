DigAll
===========================================================

![Logo](https://raw.githubusercontent.com/tacigar/minetest-digall/images/digall-logo.png)

This mod was developed inspired by DigAll, MineAll, CutAll mod for Minecraft. This mod makes it possible for players to efficiently arrange terrain, collect resources, and dig tunnels. If you dig a node with this mod enabled, you can also dig nodes around that node at the same time. It also provides some useful commands.

![Demo](https://raw.githubusercontent.com/tacigar/minetest-digall/images/digall-demo.gif)

License
-----------------------------------------------------------

Do What The Fuck You Want To Public License (WTFPL)

Usage
-----------------------------------------------------------

#### Privilege

First of all, type the following command and give digall privilege to the player. If you do not have digall privilege, you can not use the digall commands.

```
/grant <playername> digall
```

#### Chat Commands

The following is a list of commands.

| Commands            | Description                 |
| :--                 | :--                         |
| `digall:activate`   | Activate digall.            |
| `digall:deactivate` | Deactivate digall.          |
| `digall:init`       | Initialize the settings.    |
| `digall:conf`       | Display the setting screen. |
| `digall:quickmode`  | Enable / Disable QuickMode. |

#### Setting Screen

The setting screen displayed by the `digall:conf` command is shown below. On the left side of the setting screen, select the node to set. In the middle, choose how to dig. If parameters can be set for digging, it will be displayed on the right side, so please set it. For this image, you can set the digging range in the X, Y and Z directions.

![Setting Screen](https://i.imgur.com/5gT736K.png "Setting Screen")

#### Quick Mode

Type the `digall:quickmode` command to enable QuickMode. In QuickMode, only in the sneak state, you dig a node with DigAll enabled. If it is not in the sneak state, you will dig one node normally.
