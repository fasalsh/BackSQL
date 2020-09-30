#!/bin/bash
#
# Date: Apr 20 2019
# Author: Muhammed Fasal
# Company: ServerHealers ( https://serverhealers.com )
#
# Advanced MySQL Backup Script 
# Destinations: Local, FTP, Sync
# Retention: Available for Local backups
# Settings: /etc/sqladmin/settings.conf
#
# For RedHat/CentOS or Ubuntu servers
#
# Copyright (C) 2019 Muhammed Fasal
#



#Variables
MYSQL='/usr/bin/mysql'
DUMP='/usr/bin/mysqldump'

if [ -f /etc/sqladmin/settings.conf ]; then

	source /etc/sqladmin/settings.conf
else
	echo "Configuration file not found in /etc/sqladmin/"
	exit 2;
fi

if [ ! -f /root/.my.cnf ]; then
	Credentials="--defaults-extra-file=${Logins}"
else
	Credentials=""
fi

DATE=$(date +%d-%m-%Y-%H-%M)
LogFile="${LogDir}sqladmin-backup-${DATE}.log"
BackDir="${Back_Path}${DATE}/"

[ ! -d ${LogDir} ] && mkdir -p ${LogDir};
echo " SQL Database Backup Initiated on `hostname` at ${DATE} " >> ${LogFile}
echo "" >> ${LogFile}
echo "=====================================================================" >> ${LogFile}


#MySQL Status Check
sql_status() {
	mysqladmin ${Credentials} -h ${Host} -P ${Port} ping | grep -i "alive" >/dev/null
	if [ $? -eq 0 ]; then echo "[##] MySQL service running fine, so its good to initiate backup process"; else echo "[!!] MySQL is not running on this machine, exiting...."; exit 1; fi
}

#SQL Backup Function
backup() {
	if [ "${DBS}" == "ALL" ]; then
		Databases=$(mysql ${Credentials} -h ${Host} -P ${Port} -Bse 'show databases;' | grep -Ev "^(Database|mysql|performance_schema|information_schema)"$)
	else
		Databases=$DBS
	fi

	[ ! -d ${BackDir} ] && mkdir -p ${BackDir}; echo "[##] Backup Dir created at ${BackDir}" >> ${LogFile}
	db=""
	echo "---------------------------------------------" >> ${LogFile}
	echo "[**] Backup Initiating....." >> ${LogFile}
	for db in ${Databases}; do
		Full_File="${BackDir}$db.sql.gz"
		$DUMP --force ${Credentials} -h ${Host} -P ${Port} $db | gzip > ${Full_File}
		echo "[*] Database: $db :: Completed" >> ${LogFile}
		
		[ ${FTP_Enable} -eq 1 ] && backup_ftp
		[ ${Sync_Enable} -eq 1 ] && backup_sync
	done
	
}

#FTP Backup Function
backup_ftp() {
echo "[##] FTP Backup Enabled, uploading database: $db backup to the destination ${FTP_Host} : $DATE Folder " >> ${LogFile}
cd ${BackDir}
ftp -n ${FTP_Host} <<EndFTP
user "${FTP_User}" "${FTP_Pass}"
binary
hash
mkdir $DATE
cd $DATE
put $db.sql.gz
bye
EndFTP
}

#Sycn Backup Function
backup_sync() {
	echo "[##] Sync Feature Enabled, syncing database: $db backup to the destination ${Sync_Host} : ${Upload_DIR}$DATE Folder " >> ${LogFile}
	ssh -p ${Sync_Port} ${Sync_User}@${Sync_Host} mkdir  ${Upload_DIR}$DATE
	rsync -avzhP -e "ssh -p ${Sync_Port}" ${Full_File} ${Sync_User}@${Sync_Host}:${Upload_DIR}$DATE

}

#Checking Retention only if local enabled
retention() {
	if [ ${Local_Enable} -eq 1 ]; then 
		echo ""
		echo "[##] Local Backup enabled, checking retention..."
		if [ ! -z $Retention ]; then
			echo "[*] Retention value detected: $Retention " 
			# Removing old backups
			find ${Back_Path}/* -type d -mtime +$Retention -exec rm -rvf {} \;
		else
			echo "Retention value not detected from settings.conf"
		fi
	else
		echo "[!!] Local backup not enabled, so removing the backup ${BackDir}"
		 rm -rvf ${BackDir};
	fi
}

#Report Send
report_send() {
	if [ ${Email_Enable} -eq 1 ]; then
		mail -s "Database Backup Report [`hostname`]: $DATE" ${EMAIL_ADDR} < ${LogFile}
	fi
} 	

#Main Function
main() {
	sql_status >> ${LogFile}
	backup
	retention >> ${LogFile}
	echo "************************ Backup Completed ************************" >> ${LogFile}
        echo " Check Backups at ${BackDir} and Log on ${LogDir} " >> ${LogFile}
        echo "******************************************************************" >> ${LogFile}
	report_send
}

# MAIN FUNCTION CALL
main
