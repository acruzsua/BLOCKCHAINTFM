#!/bin/bash


kill_ganache_cli () {
  ganache_cli_pid=$(ps ax | grep ganache-cli | grep -v grep | awk '{print $1}')
  if [ $ganache_cli_pid ]; then
    kill -9 $(ps ax | grep ganache-cli | grep -v grep | awk '{print $1}')
  fi
}


kill_ganache_cli

ganache-cli --account="0x81e5de30c507c7c49ac40f7e3cf876c197e2283d33565b5b5062b98da7f21b34,100000000000000000000" --account="0x5a7941f7b1661200da7029a7df10d9a6870391f065e1caa6fb358d574a64e816,100000000000000000000" --account="0x3c053e0b0c9f5c4aef51182ceaa006dab3d4bba05bd2b9c055d80dfc34ffd070,100000000000000000000" --account="0x42a44e2324dafa1207a9f7ae7b9452f7f431ec3a4f6c842b8564eb8e854ed0af,100000000000000000000" &

sleep 15

if truffle migrate; then
  truffle console < initial_truffle_console.sh &
else
  echo Failed!!
  kill_ganache_cli 
fi

