#!/bin/sh

/usr/bin/mysqladmin status

if [ $? -ne 0 ]; then
  exit 1
else
  exit 0
fi
