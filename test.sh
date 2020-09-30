#!/bin/bash

FTP_Host="serverlogs.cf"
FTP_Port=21
FTP_User="fasal@serverlogs.tk"
FTP_Pass="sNQT5lZSIyDxg"
Upload_DIR="~/"
BackDir="/backup/DB-Backup/19-04-2019-15-09/"

ftp -n ${FTP_Host} <<EndFTP
user "${FTP_User}" "${FTP_Pass}"
binary
hash
cd ${Upload_DIR}
mkdir test
bye
EndFTP

