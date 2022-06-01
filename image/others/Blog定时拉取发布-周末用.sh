#!/bin/bash

cd /Users/yons/gitee/hexo-blog 

for ((i=1; i<=160; i++))
do
	git pull;
    hexo clean;
    hexo g;
    hexo d;
    sleep 300;
    hexo d;
    sleep 3300;
done

