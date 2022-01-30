# ``glink``
Communication between Discord and Garrysmod

## Requires
* [gwsockets](https://github.com/FredyH/GWSockets)
* [gmsv_reqwest](https://github.com/WilliamVenner/gmsv_reqwest) or [gmod-chttp](https://github.com/timschumi/gmod-chttp)

## Usage
Set ``DISCORD_TOKEN``, ``DISCORD_BOT_ID``, ``DISCORD_LINK_CHANNEL_ID`` and ``DISCORD_WEBHOOK`` with the lua ``cookie`` library.

(Optionally ``DISCORD_AVATAR``)

E.g. run this in the server console:
```lua
cookie.Set("DISCORD_TOKEN", "blablablablabla")
```