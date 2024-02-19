@echo off

"axm68k.exe" /m /k /p "SonicCD (Sub CPU).asm", "SonicCD (Sub CPU).bin" >errors1.txt, "SonicCD (Sub CPU).sym", "SonicCD (Sub CPU).lst"
type errors1.txt

IF NOT EXIST "SonicCD (Sub CPU).bin" PAUSE & EXIT 2

echo Processing Sub CPU symbols.
"convsym.exe" "SonicCD (Sub CPU).sym" "SonicCD Sub CPU Symbols.bin"

"mdcomp/koscmp.exe"	"SonicCD Sub CPU Symbols.bin" "SonicCD Sub CPU Symbols.kos"

echo Compressing Sub CPU program.
 "Modulise.exe" "mdcomp/koscmp.exe" $2000 "SonicCD (Sub CPU).bin" "SonicCD (Sub CPU).kosm" -noindex -nolast -actualcount

IF NOT EXIST "SonicCD (Sub CPU).kosm" PAUSE & EXIT 2

echo Assembling Main CPU Program.
"axm68k.exe" /m /k /p "SonicCD (Main CPU).asm", "SonicCD Mode 1.bin" >errors2.txt, "SonicCD Main CPU Symbols.sym", "SonicCD Mode 1.lst"
type errors2.txt

"convsym.exe" "SonicCD Main CPU Symbols.sym" "SonicCD Main CPU Symbols.bin"

echo Processing Main CPU symbols.
"mdcomp/koscmp.exe"	"SonicCD Main CPU Symbols.bin" "SonicCD Main CPU Symbols.kos"

rem Append compressed main CPU symbols to end of ROM.
copy /b "SonicCD Mode 1.bin"+ "SonicCD Main CPU Symbols.kos" "SonicCD Mode 1.bin" /y


pause