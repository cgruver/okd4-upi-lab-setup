#!/bin/sh

/usr/bin/mysql -D mysql -e 'SELECT 1'

if [ $? -ne 0 ]; then
  exit 1
else
  exit 0
fi
