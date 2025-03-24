# PoGOGamemaster

This is an internal package used by the main package PoGOBase. It is not
intended for users or even most developers.

PoGOGamemaster is provided as a standalone sub-package so that it can be loaded
independently of PoGOBase. When PoGOBase is built (see
`PoGOBase/deps/build.jl`), PoGOGamemaster is used to parse the gamemaster JSON
file. Once the necessary data have been extracted, the result is saved to
`PoGOBase/deps/gamemaster.ser` in Julia serialized format. PoGOGamemaster
and this file (but *not* the JSON version) are loaded by PoGOBase to
populate a set of `const` variables in `PoGOBase/src/consts.jl`.

This two-stage build process makes PoGOBase much lighter and faster to load.
