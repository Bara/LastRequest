#!/bin/bash

echo -e "Download und extract sourcemod\n"
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo -e "Give compiler rights for compile\n"
chmod +x addons/sourcemod/scripting/spcomp

echo -e "Compile last request plugins\n"
for file in addons/sourcemod/scripting/*.sp
do
  echo -e "\nCompiling $file..." 
  addons/sourcemod/scripting/spcomp -E -v0 $file
done
