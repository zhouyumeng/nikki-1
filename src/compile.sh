#!/bin/bash

# to abort in case of errors

function error {
echo aborted due to an error
exit 1
}
trap error ERR

echo This is a simple script, trying to make it easy to compile Nikki. Look at README for more details.
echo This is tested on linux and on windows using msys
echo You can create a file called "ghc_options" that contains options that will be passed to any calls of ghc.

if [ -f ghc_options ]
then
    GHC_OPTIONS=$(cat ghc_options)
else
    GHC_OPTIONS=""
fi

cd buildSystem
ghc --make -i../common Main.hs -o build $GHC_OPTIONS
cd ..
buildSystem/build build_application

