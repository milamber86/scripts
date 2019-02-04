#!/bin/bash
for DATE in 2019010 2019011 2019012 2019013
 do
  for DIR in $(ls -1 /maildata/icewarp/mail/homecredit.cn/)
    do
     for I in $(find "${DIR}" -type f -name "0*${DATE}*.imap")
	do 
	 prdel="$(awk 'BEGIN{FS=" "; RS"\n"} ($1=="Subject:" && $0~"The POS Visiting in SMT in Jan") {print $0} NR==50{exit}' "${I}")"
	 [[ ! -z ${prdel} ]] && echo "${I}" | tee /root/searchlog.txt
        done
    done
 done
exit 0
