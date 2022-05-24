# bweeper

A (very primitive) minesweeper game designed to fit within a boot sector, i.e.
512 bytes. It's not the most efficiently coded as far as boot sector games go,
and was mostly programmed for fun over the course of a weekend.

This game exclusively uses 8086 instructions so it should run on any PC emulator
with support higher than that, although this has only been tested on QEMU. Run
on real hardware at your own risk.

## Building
Simply run `make` in the repository root. Requires [NASM](https://www.nasm.us/)
to build.

## Controls
<kbd>↑</kbd> <kbd>↓</kbd> <kbd>←</kbd> <kbd>→</kbd> Move  
<kbd>C</kbd> Clear Tile  
<kbd>X</kbd> Flag Tile  

## Screenshots

![ss01](/images/ss01.png)

![ss02](/images/ss02.png)

## TO-DO
- Add win-loss checks
- Add option to reset after game finished