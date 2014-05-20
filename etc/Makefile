every1hour: trmon

trmon:
	@${HOME}/trmon/bin/tr.pl ${HOME}/trmon/etc/tr.mon
	@find ${HOME}/trmon/data/tr -name "*.rrd" -mtime +30 -exec rm '{}' \;
