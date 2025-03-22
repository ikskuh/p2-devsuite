# Propeller 2 Development Suite

[![Build](https://github.com/ikskuh/p2-devsuite/actions/workflows/build.yml/badge.svg)](https://github.com/ikskuh/p2-devsuite/actions/workflows/build.yml)

This repository contains a build script which compiles a collection of tools for development of [Parallax Propeller 2](https://www.parallax.com/propeller-2/) software.

Included software packages:

- [spin2cpp, flexcc, flexspin](https://github.com/totalspectrum/spin2cpp) v7.1.1
- [loadp2](https://github.com/totalspectrum/loadp2) v075

## Compilation

Get a copy of [Zig 0.14](https://ziglang.org/download/#release-0.14.0) for your system, then invoke

```sh-session
[user@work p2-devsuite]$ zig build
[user@work p2-devsuite]$ tree zig-out
zig-out
└── bin
    ├── flexcc
    ├── flexspin
    ├── include
    │   ├── assert.h
    │   ├── …
    │   └── wctype.h
    ├── loadp2
    └── spin2cpp

26 directories, 327 files
[user@work p2-devsuite]$ 
```
