# cleanup old logs
rm -f /usr/local/nginx/logs/xvs_mp4.txt /usr/local/nginx/logs/xvs_hls2.txt

# rename nginx logs
mv -f /usr/local/nginx/logs/traffic_mp4.log /usr/local/nginx/logs/xvs_mp4.txt
mv -f /usr/local/nginx/logs/traffic_hls2.log /usr/local/nginx/logs/xvs_hls2.txt

#killall -USR1 nginx
# reopen nginx logs
/usr/local/nginx/sbin/nginx -s reopen

# run parsers
./nginx_hls2.pl
