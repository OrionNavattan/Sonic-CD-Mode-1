@echo off

"axm68k.exe" /m /k /p "SonicCD (Sub CPU).asm", "SonicCD (Sub CPU).bin" >errors1.txt, "SonicCD (Sub CPU).sym", "SonicCD (Sub CPU).lst"
type errors1.txt

IF NOT EXIST "SonicCD (Sub CPU).bin" PAUSE & EXIT 2

echo Compressing Sub CPU program; this may take a couple minutes.
 "Modulise.exe" "mdcomp/koscmp.exe" $2000 "SonicCD (Sub CPU).bin" "SonicCD (Sub CPU).kosm" -noindex -nolast -actualcount

IF NOT EXIST "SonicCD (Sub CPU).kosm" PAUSE & EXIT 2

echo Assembling Main CPU Program.
"axm68k.exe" /m /k /p "SonicCD (Main CPU).asm", "SonicCD Mode 1.bin" >errors2.txt, SonicCD Mode 1.sym", "SonicCD Mode 1.lst"
type errors2.txt

pause