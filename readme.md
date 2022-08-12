# Calamari
Utility for building and running [Cuttlefish](https://github.com/LeotomasMC/Cuttlefish).

### Why a custom build tool?
The older tool using [`hxp`](https://github.com/OpenFL/hxp) worked fine for a while, but once I started supporting older Minecraft versions, I wanted a tool that could automatically build Cuttlefish, run the required data generators with an official server jar, put the files in the correct place, and then run the server. While I technically could do this using hxp, it would be a bit slower than a custom tool, as hxp interprets the build script, instead of it being compiled.