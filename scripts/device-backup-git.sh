#!/bin/bash

VERSION="DB-1.8";
RS=0;

R1="^([0-9]{1,3})@"
R1+="([a-z]+)@"
R1+="([a-z]+)@"
R1+="([A-Z]{3,4})?@"
R1+="([a-zA-Z_]+)?@"
R1+="([0-9a-zA-Z\/?~^!$%&.;|<#]+)?@"
R1+="([0-9a-zA-Z\.|#]+)?@"
R1+="([0-9A-Za-z\.\-]+)@"
R1+="([0-9]+)?"
R1+="(@(([a-z0-9]+)=\"([0-9A-Za-z: -./]+)\"))?$";

DEVFILE="";
DEVFILEPASS="";
GITDIR="";
DLST="";
CMNT="";
DOLS=0;
VERB=0;
GITPP=1;
CRBC=0;
SSHO=0;
SSHEXECONF="";
NEWPASS="";
ORPASS="";
CUSER="admin";
EXPECT="/usr/bin/expect";
OPENSSL="/usr/bin/openssl";
EXPECTAGR="-nN -f -";

OPENSSL_OPT="-pbkdf2 -iter 1000 -aes-256-cbc -md SHA256";

if ! [ -x "$(command -v git)" ]; then
  echo 'Error: program expect is not installed.' >&2
  echo 'Run: apt install expect' >&2
  exit 1
fi


while getopts ":d:f:n:c:P:S:u:plvLrkbB" opt; do
	case $opt in
		f) DEVFILE="${OPTARG}";;
		d) GITDIR="${OPTARG}";;
		n) DLST="${OPTARG}";;
		c) CMNT="${OPTARG}";;
		b) CRBC=2;;
		B) CRBC=1;;
		k) SSHO=1;;
		l) DOLS=1;;
		L) DOLS=2;;
		r) GITPP=0;;
    S) SSHEXECONF="${OPTARG}";;
		v) VERB=1;;

		p) read -s -p "DEVFILE Password: " DEVFILEPASS;;
		:) echo "Option -$OPTARG requires an argument." >&2;exit 1;;
		\?) echo "Invalid option: -$OPTARG" >&2;exit 1;;
	esac;
done;
case "$TERM" in
    *dumb*) INTERACT=0;;
    *)      INTERACT=1;;
esac;

if [ "${VERB}" -eq 2 ]; then
	echo -ne "Contact: Corey DeLasaux <corey.delasaux@netapp.com>\n<cordelster@gmail.com>\nVersion: ""$VERSION""\n\n";
	exit 0
fi;
GITDIR=`sed 's/\/$//' <<<"${GITDIR}"`;

if [ -z "${GITDIR}" ] && [ ! -z "${MY_GIT_BACKUP_DIR}" ]; then
	GITDIR="${MY_GIT_BACKUP_DIR}";
fi;

#GITDIR=`realpath "${GITDIR}" 2>/dev/null `;
function cursorBack() {
  echo -en "\033[$1D"
}
function spinner() {
  local LC_CTYPE=C
  local pid=$1
  case $(($RANDOM % 12)) in
  0)
    local spin='⠁⠂⠄⡀⢀⠠⠐⠈'
    local charwidth=3
    ;;
  1)
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    local charwidth=3
    ;;
  2)
    local spin="▁▂▃▄▅▆▇█▇▆▅▄▃▂▁"
    local charwidth=3
    ;;
  3)
    local spin="▉▊▋▌▍▎▏▎▍▌▋▊▉"
    local charwidth=3
    ;;
  4)
    local spin='←↖↑↗→↘↓↙'
    local charwidth=3
    ;;
  5)
    local spin='▖▘▝▗'
    local charwidth=3
    ;;
  6)
    local spin='┤┘┴└├┌┬┐'
    local charwidth=3
    ;;
  7)
    local spin='◢◣◤◥'
    local charwidth=3
    ;;
  8)
    local spin='◰◳◲◱'
    local charwidth=3
    ;;
  9)
    local spin='◴◷◶◵'
    local charwidth=3
    ;;
  10)
    local spin='◐◓◑◒'
    local charwidth=3
    ;;
  11)
    local spin='-\|/'
    local charwidth=1
    ;;
  esac

  local i=0
  tput civis
	while kill -0 $pid 2>/dev/null; do
    local i=$(((i + $charwidth) % ${#spin}))
  printf "%s" "${spin:$i:$charwidth}"

    cursorBack 1
    sleep .1
	done
	tput cnorm
wait $pid # capture exit code
return $?
}

get_password () {
	while :
	do
		echo "May the password be with you!"
		read -sp "New Password:" NEWPASS
		read -sp " again:" VNEWPASS
			if [ "$VNEWPASS" != "$NEWPASS" ]; then
			  echo " Passwords don't match!"
			elif [ "$NEWPASS" == "" ]; then
			  echo " Password can not be null"
			elif [ "$VNEWPASS" == "$NEWPASS" ]; then
				echo ""
				break;
	    fi
  done
}

echo "";
if [ "${CRBC}" -eq 2 ]; then
	GROPTS="username";
else
	GROPTS="username admin password";
fi;
GREPARGS="switchname|^hostname|"${GROPTS}"|^feature interface-vlan|^ssh|vrf context|vrf member|ip domain-name|ip name-server|^interface Vlan|^snmp-server|ip route|ip address|^interface mgmt0|^line|no system default|logging console";
if [ "${DOLS}" -eq 0 ] && [ ! -d "${GITDIR}" ]; then
	echo "GIT folder does not exit: ${GITDIR}";
else if [ ! -f "${DEVFILE}" ]; then
	echo "File not found: "${DEVFILE}"";
else
CHANGES=0;
  if [ "${DOLS}" -eq 0 ] && [ "${GITPP}" -eq 1 ]; then git -C "${GITDIR}" pull; fi;

  if [ "${VERB}" -eq 1 ]; then
	  EXPECTAGR="-dnN -f -";
  fi;
  if [ "${SSHEXECONF}" != "" ]; then
	  if [ -f "$SSHEXECONF" ]; then
	    SSHEXEC="ssh -F ${SSHEXECONF} ";
	  else
		  echo "ssh config file not found. Trying to continue."
		  SSHEXEC="ssh ";
	  fi;
  else
	 SSHEXEC="ssh ";
  fi;

function invoke_main () {
trap - INT
if [ ${?} -eq 0 ]; then while read L; do if [[ ${L} =~ ${R1} ]]; then
	HNUM="${BASH_REMATCH[1]}";
	HTYP="${BASH_REMATCH[2]}";
	STYP="${BASH_REMATCH[3]}";
	ATYP="${BASH_REMATCH[4]}";
	USER="${BASH_REMATCH[5]}";
	PASS="${BASH_REMATCH[6]}";
	ENBL="${BASH_REMATCH[7]}";
	HOST="${BASH_REMATCH[8]}";
	PORT="${BASH_REMATCH[9]}";
	ADTP="${BASH_REMATCH[12]}"; # additional parameter type
	ADVU="${BASH_REMATCH[13]}"; # additional parameter value

	if [ -n "${DLST}" ]; then
		if ! [[ " ${DLST} " =~ " ${HNUM} " ]]; then
			continue;
		fi;
	fi;
	###### CLEAN ME UP
	if [ "${STYP}" == "sshnokey" ]; then
		STYP="ssh";
		SSHOC=1;
	else
		SSHOC=0;
	fi;
	if [ "${SSHO}" -eq 1 ] || [ "${SSHOC}" -eq 1 ]; then
		SSHC="${SSHEXEC}-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ";
	else
		SSHC="${SSHEXEC}";
	fi;
	#################
	if [ "${VERB}" -eq 1 ]; then
		echo -ne "\n\nVERSION: ""${VERSION}""\nSSH: ""${SSHC}""\n\nHNUM: ""${HNUM}""\nHTYP: ""${HTYP}""\nSTYP: ""${STYP}""\nATYP: ""${ATYP}""\nUSER: ""${USER}""\nPASS: ""${PASS}""\nENBL: ""${ENBL}""\nHOST: ""${HOST}""\nPORT: ""${PORT}""\nADTP: ""${ADTP}""\nADVU: ""${ADVU}""\n";
	fi;

	if [ "${DOLS}" -eq 1 ]; then
		echo "${HNUM}"	"${HOST}";
		continue;
	fi;
	if [ "${DOLS}" -eq 2 ]; then
		echo "${L}";
		continue;
	fi;

	FILE=""${GITDIR}"/"${HOST}".cfg";
	BFILE=""${GITDIR}"/reset/"${HOST}"-"${VERSION}"-RESET.cfg";

	RSYNCDIRS="/etc";

	RSYNCC="rsync --delete-excluded -r -a -p ";

	RSYNCSUDOC="rsync --delete-excluded --relative --rsync-path \"sudo rsync\" -r -a -p ";

	case "${ADTP}" in
		"rsyncdirs")
			RSYNCDIRS=${ADVU};
		;;
	esac;

	case "${HTYP}" in
		"linux")
			case "${STYP}" in
				"rsynclocal")
					mkdir -p "${GITDIR}"/"${HOST}"/ || exit 1;
					expc="set timeout 120\n";
					expc+="log_user 0\n";
					expc+="spawn "${RSYNCC}" -R "${RSYNCDIRS}" "${GITDIR}"/"${HOST}"/\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*command not found*\" { send_user 'rsync\ not\ found'; exit 1 }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { exit 0 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="exit 1\n";
				;;
				"rsync")
					mkdir -p "${GITDIR}"/"${HOST}"/ || exit 1;
					expc="set timeout 120\n";
					expc+="log_user 0\n";
					expc+="spawn "${RSYNCC}" "${USER}"@"${HOST}":"${RSYNCDIRS}" "${GITDIR}"/"${HOST}"/\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*command not found*\" { send_user 'rsync\ not\ found'; exit 1 }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { exit 0 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="exit 1\n";
					;;
				"rsyncsudo")
					mkdir -p "${GITDIR}"/"${HOST}"/ || exit 1;
					expc="set timeout 120\n";
					expc+="log_user 0\n";
					expc+="spawn "${RSYNCSUDOC}" "${USER}"@"${HOST}":"${RSYNCDIRS}" "${GITDIR}"/"${HOST}"/\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*nexpected local arg*\" { send_user 'sudo\ unexpected\ local\ arg'; exit 1 }\n";
					expc+="\"\[sudo\] *:\" { send_user 'sudo\ requires\ password'; exit 1 }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*command not found*\" { send_user 'rsync\ not\ found'; exit 1 }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { exit 0 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="exit 1\n";
					;;
				*)
					expc="send_user 'unknown'\nexit 1\n";
					;;
			esac;
			;;
		"ibmbnt")
			case "${STYP}" in
				"tel")
					expc="set timeout 3\n";
					expc+="log_user 0\n";
					expc+="spawn telnet "${HOST}" "${PORT}"\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*Could not resolve*\" { send_user 'Temporary\ failure\ in\ nameresolution'; exit 1 }\n";
					expc+="\"*Enter  password:\" { send -- ""${PASS}""\\\r\\\n }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*Password incorrect.\" { send_user 'password\ incorrect'; exit 1 }\n";
					expc+="\"*Main#\" { send -- \"cfg\\\r\\\n\"; sleep 1; break }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { send_user 'eof'; exit 1 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="expect \"*Configuration#\" { send -- \"lines 0\\\r\\\n\"; sleep 1 }\n";
					expc+="expect \"*Configuration#\" { send -- \"dump\\\r\\\n\" }\n";
					expc+="log_user 1\n";
					expc+="expect \"*Configuration#\" { log_user 0; send -- \"exit\\\r\\\n\"; exit 0 }\n";
					expc+="log_user 0\n";
					expc+="exit 1\n";
					;;
				*)
					expc="send_user 'unknown'\nexit 1\n";
					;;
			esac;
			;;
		"cisco")
			case "${STYP}" in
				"ssh")
					expc="set timeout 12\n";
					expc+="log_user 0\n";
					expc+="spawn "${SSHC}" "${USER}"@"${HOST}"\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*assword:\" { send -- \"""${PASS}""\\\r\\\n\" }\n";
					expc+="\"no matching *\" { send_user 'MAC_keyexchange_NOMATCH'; exit 1 }\n";
					expc+="\"*key verification failed*\" { send_user 'WARNING_SSH_key_CHANGED!'; exit 1 }\n";
					expc+="\"*he authenticity of host*\" { send_user 'unkown_ssh_key'; exit 1 }\n";
					expc+="\"*Too many authentication failures*\" { send_user 'ssh_auth_failed'; exit 1 }\n";
					expc+="\"*>\" { send -- \"enable\n\";\sleep 1;\n";
					expc+="while 1 {\n";
					expc+="expect \"*assword:\" { send -- \"""${ENBL}""\n\"; sleep 1;break }\n";
					expc+="expect \"*denied*\" { send_user 'denied'; exit 1 }\n";
					expc+="}\n";
					expc+="}\n";
					expc+="\"*#\" { send -- \"terminal length 0\\\r\\\n\"; sleep 1; break }\n";
					expc+="\"*denied*\" { send_user 'denied'; exit 1 }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="eof { send_user 'eof'; exit 1 }\n";
					expc+="}\n";
					expc+="}\n";

					if [ "$NEWPASS" != "" ]; then
						expc+="expect \"*#\" { send -- \"config term\\\r\\\n\"; sleep 1;\n";
  					expc+="expect \"% Invalid command at marker*\" { send_user 'Invaild_command'; exit 1 }\n";
						expc+="expect \"*(config)#\" { send -- \"username ${CUSER} password ${NEWPASS}\\\r\\\n\";\sleep 1;}\n";
						expc+="while 1 {\n";
            expc+="expect {\n";
						expc+="\"Special characters*\" { send_user 'CHAR_password'; exit 1 }\n";
						expc+="\"Wrong Password*\" { send_user 'Invaild_password'; exit 1 }\n";
						expc+="\"password is weak*\" { send_user 'Weak_password'; exit 1 }\n";
						expc+="\"cannot make changes*\" { send_user 'Wrong_privilage'; exit 1 }\n";
						expc+="\"*(config)# \" { send -- \"copy running-config startup-config\\\r\\\n\"; sleep 5; break }\n";
						expc+="}\n";
            expc+="}\n";
						expc+="expect \"*(config)#\" { send -- \"exit\\\r\\\n\";\sleep 1; sleep 1 }\n";
					else
						expc+="log_user 1\n";
						expc+="expect \"*#\" { send -- \"show running-config view full\\\r\\\n\"; sleep 1;\n";
						expc+="expect \"*nvalid input*\" { send -- \"show running-config\\\r\\\n\" }\n";
						expc+="expect \"*nvalid command*\" { send -- \"show running-config\\\r\\\n\" }\n";
				  fi;
					expc+="expect \"*nvalid command at*\" { send_user 'Invaild_command'; exit 1 }\n";
					expc+="expect # { send -- \"exit\\\r\\\n\"; exit 0 }\n";
					expc+="}\n";
					expc+="log_user 0\n";
					expc+="exit 1\n";
					;;
				"tel")
					expc="set timeout 3\n";
					expc+="log_user 0\n";
					expc+="spawn telnet "${HOST}"\n";
					expc+="while 1 {\n";
					expc+="expect {\n";
					expc+="\"*sername:\" { send -- ""${USER}""\\\r }\n";
					expc+="\"*assword:\" { send -- ""${PASS}""\\\r }\n";
					expc+="\"*denied*\" { send_user 'denied'; exit 1 }\n";
					expc+="\"*failed*\" { send_user 'denied'; exit 1 }\n";
					expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
					expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
					expc+="\"*>\" { send_user 'permission'; exit 1 }\n";
					expc+="\"*#\" { send -- \"terminal length 0\\\r\"; break }\n";
					expc+="timeout { send_user 'timeout'; exit 1 }\n";
					expc+="}\n";
					expc+="}\n";
					if [ "$NEWPASS" != "" ]; then
						expc+="expect \"*#\" { send -- \"config term\\\r\\\n\"; sleep 1;\n";
  					expc+="expect \"% Invalid command at marker*\" { send_user 'Invaild_command'; exit 1 }\n";
						expc+="expect \"*(config)#\" { send -- \"username ${CUSER} password ${NEWPASS}\\\r\\\n\";\sleep 1;}\n";
						expc+="while 1 {\n";
            expc+="expect {\n";
						expc+="\"Special characters*\" { send_user 'CHAR_password'; exit 1 }\n";
						expc+="\"Wrong Password*\" { send_user 'Invaild_password'; exit 1 }\n";
						expc+="\"password is weak*\" { send_user 'Weak_password'; exit 1 }\n";
						expc+="\"cannot make changes*\" { send_user 'Wrong_privilage'; exit 1 }\n";
						expc+="\"*(config)# \" { send -- \"copy running-config startup-config\\\r\\\n\"; sleep 5; break }\n";
						expc+="}\n";
            expc+="}\n";
						expc+="expect \"*(config)#\" { send -- \"exit\\\r\\\n\";\sleep 1; sleep 1 }\n";
					else
						expc+="log_user 1\n";
						expc+="expect \"*#\" { send -- \"show running-config view full\\\r\" }\n";
						expc+="expect \"*nvalid input*\" { send -- \"show running-config\\\r\" }\n";
						expc+="expect \"*nvalid command*\" { send -- \"show running-config\\\r\\\n\" }\n";
					fi;
					expc+="expect # { send -- \"exit\\\r\"; exit 0 }\n";
					expc+="log_user 0\n";
					expc+="exit 1\n";
					;;
        *)
          expc="send_user 'unknown'\nexit 1\n";
          ;;
        esac;
                        ;;
		  "nxos")
		    case "${STYP}" in
		      "ssh")
		              expc="set timeout 12\n";
		              expc+="log_user 0\n";
		              expc+="spawn "${SSHC}" "${USER}"@"${HOST}"\n";
		              expc+="while 1 {\n";
		              expc+="expect {\n";
		              expc+="\"*assword:\" { send -- \"""${PASS}""\\\r\\\n\" }\n";
									expc+="\"no matching *\" { send_user 'MAC_keyexchange_NOMATCH'; exit 1 }\n";
		              expc+="\"*key verification failed*\" { send_user 'WARNING_SSH_key_CHANGED!'; exit 1 }\n";
		              expc+="\"*he authenticity of host*\" { send_user 'unknown_ssh_key'; exit 1 }\n";
		              expc+="\"*Too many authentication failures*\" { send_user 'ssh_auth_failed'; exit 1 }\n";
		              expc+="\"*>\" { send -- \"enable\n\";\sleep 1;\n";
		              expc+="while 1 {\n";
		              expc+="expect \"*assword:\" { send -- \"""${ENBL}""\n\"; sleep 1;break }\n";
		              expc+="expect \"*denied*\" { send_user 'denied'; exit 1 }\n";
		              expc+="}\n";
		              expc+="}\n";
		              expc+="\"*#\" { send -- \"terminal length 0\\\r\\\n\"; sleep 1; break }\n";
		              expc+="\"*denied*\" { send_user 'denied'; exit 1 }\n";
		              expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
		              expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
		              expc+="timeout { send_user 'timeout'; exit 1 }\n";
		              expc+="eof { send_user 'eof'; exit 1 }\n";
		              expc+="}\n";
		              expc+="}\n";

									if [ "$NEWPASS" != "" ]; then
										expc+="expect \"*#\" { send -- \"config term\\\r\\\n\"; sleep 1;\n";
				  					expc+="expect \"% Invalid command at marker*\" { send_user 'Invaild_command'; exit 1 }\n";
										expc+="expect \"*(config)#\" { send -- \"username ${CUSER} password ${NEWPASS}\\\r\\\n\";\sleep 1;}\n";
										expc+="while 1 {\n";
				            expc+="expect {\n";
										expc+="\"Special characters*\" { send_user 'CHAR_password'; exit 1 }\n";
										expc+="\"Wrong Password*\" { send_user 'Invaild_password'; exit 1 }\n";
										expc+="\"password is weak*\" { send_user 'Weak_password'; exit 1 }\n";
										expc+="\"cannot make changes*\" { send_user 'Wrong_privilage'; exit 1 }\n";
										expc+="\"*(config)# \" { send -- \"copy running-config startup-config\\\r\\\n\"; sleep 5; break }\n";
										expc+="}\n";
				            expc+="}\n";
										expc+="expect \"*(config)#\" { send -- \"exit\\\r\\\n\";\sleep 1; sleep 1 }\n";
									else
									expc+="log_user 1\n";
		              expc+="expect \"*#\" { send -- \"show running-config\\\r\\\n\"; sleep 1;\n";
		              expc+="expect \"% Invalid command at marker*\" { send_user 'Invaild_command'; exit 1 }\n";
								fi;
		              expc+="expect # { send -- \"exit\\\r\\\n\"; exit 0 }\n";
		              expc+="}\n";
		              expc+="log_user 0\n";
		              expc+="exit 1\n";
		              ;;
		     "tel")
		              expc="set timeout 3\n";
		              expc+="log_user 0\n";
		              expc+="spawn telnet "${HOST}"\n";
		              expc+="while 1 {\n";
		              expc+="expect {\n";
		              expc+="\"*sername:\" { send -- ""${USER}""\\\r }\n";
		              expc+="\"*assword:\" { send -- ""${PASS}""\\\r }\n";
		              expc+="\"*denied*\" { send_user 'denied'; exit 1 }\n";
		              expc+="\"*failed*\" { send_user 'denied'; exit 1 }\n";
		              expc+="\"*refused*\" { send_user 'refused'; exit 1 }\n";
		              expc+="\"*not known*\" { send_user 'notknown'; exit 1 }\n";
		              expc+="\"*>\" { send_user 'permission'; exit 1 }\n";
		              expc+="\"*#\" { send -- \"terminal length 0\\\r\"; break }\n";
		              expc+="timeout { send_user 'timeout'; exit 1 }\n";
		              expc+="}\n";
		              expc+="}\n";

									if [ "$NEWPASS" != "" ]; then
										expc+="expect \"*#\" { send -- \"config term\\\r\\\n\"; sleep 1;\n";
				  					expc+="expect \"% Invalid command at marker*\" { send_user 'Invaild_command'; exit 1 }\n";
										expc+="expect \"*(config)#\" { send -- \"username ${CUSER} password ${NEWPASS}\\\r\\\n\";\sleep 1;}\n";
										expc+="while 1 {\n";
				            expc+="expect {\n";
										expc+="\"Special characters*\" { send_user 'CHAR_password'; exit 1 }\n";
										expc+="\"Wrong Password*\" { send_user 'Invaild_password'; exit 1 }\n";
										expc+="\"password is weak*\" { send_user 'Weak_password'; exit 1 }\n";
										expc+="\"cannot make changes*\" { send_user 'Wrong_privilage'; exit 1 }\n";
										expc+="\"*(config)# \" { send -- \"copy running-config startup-config\\\r\\\n\"; sleep 5; break }\n";
										expc+="}\n";
				            expc+="}\n";
										expc+="expect \"*(config)#\" { send -- \"exit\\\r\\\n\";\sleep 1; sleep 1 }\n";
									else
									  expc+="log_user 1\n";
			              expc+="expect \"*#\" { send -- \"show running-config\\\r\" }\n";
									fi;
		              expc+="expect # { send -- \"exit\\\r\"; exit 0 }\n";
		              expc+="log_user 0\n";
		              expc+="exit 1\n";
		              ;;
						*)
							expc="send_user 'unknown'\nexit 1\n";
							;;
					esac;
					;;
				*)
					expc="send_user 'unknown'\nexit 1\n";
					;;
			esac;

	size=0;
	outex=$(echo -e "${expc}" | ${EXPECT} ${EXPECTAGR});

	if [ ${?} -eq 0 ]; then
		case "${HTYP}" in
			"linux")
				case "${STYP}" in
					"rsync" | "rsyncsudo" | "rsynclocal")
						size=$(du -bs "${GITDIR}"/"${HOST}" | cut -f 1);
						if [ ${size} -ge 5000 ]; then
							echo "OK: "${HOST}"";
							((GOOD++));
							git -C "${GITDIR}" add "${HOST}";
							CHANGES=1;
						else
							echo "ERROR: "${HOST}" status: size: "${size}"";
							((BAD++));
							RS=1;
						fi;
						;;
				esac;
				;;
        "nxos")
                echo  "${outex}" | sed -n '/!/,/^end/p' | egrep -v "Time:" > "${FILE}";
                size=$(wc -c <"${FILE}");
                if [ ${size} -ge 2900 ]; then
                        echo "OK: "${HOST}"";
												((GOOD++));
								if [ "${CRBC}" -ge 1 ]; then
									if [ ! -d "${GITDIR}/reset" ]; then
										mkdir "${GITDIR}/reset"
									fi;
									echo "${outex}" | grep -ahE "${GREPARGS}" > "${BFILE}";
									if [ "${GITPP}" -eq 1 ]; then
										git -C "${GITDIR}" add "${BFILE}";
									fi;
								fi;
								if [ "${GITPP}" -eq 1 ]; then
									git -C "${GITDIR}" add "${FILE}";
								fi;
	          	CHANGES=1;
	              else
	                      echo "ERROR: "${HOST}" status: size: "${size}"";
												((BAD++));
	                      RS=1;
	              fi;
	              ;;
			*)
				echo  "${outex}" | sed -n '/!/,/^end/p' | egrep -v "ntp clock-period" > "${FILE}";
				size=$(wc -c <"${FILE}");
				if [ ${size} -ge 2900 ]; then
					echo "OK: "${HOST}"";
					((GOOD++));
					if [ "${CRBC}" -ge 1 ]; then
						if [ ! -d "${GITDIR}/reset" ]; then
							mkdir "${GITDIR}/reset"
						fi;

						echo "${outex}" | grep -ahE "${GREPARGS}" > "${BFILE}";
						if [ "${GITPP}" -eq 1 ]; then
							git -C "${GITDIR}" add "${BFILE}";
						fi;
					fi;
					if [ "${GITPP}" -eq 1 ]; then
						git -C "${GITDIR}" add "${FILE}";
					fi;
					CHANGES=1;
				else
					echo "ERROR: "${HOST}" status: size: "${size}"";
					((BAD++));
					RS=1;
				fi;
				;;
		esac;
	else
		echo "ERROR: "${HOST}" status: "${outex}"";
		((BAD++));
		RS=1;
	fi;
else
	echo "ERROR: Wrong device's string: "${L}""
	RS=1;
fi;
done < <((\
if [ -z "${DEVFILEPASS}" ]; then \
	cat "${DEVFILE}"; \
else \
	"${OPENSSL}" enc -in "${DEVFILE}" ${OPENSSL_OPT} -d -pass pass:"${DEVFILEPASS}"; \
fi;) | egrep -v "^( +)?#.*$|^$" | sort -u | sort -t@ -n);
    if [ ${CHANGES} -eq 1 ] && [ "${GITPP}" -eq 1 ]; then
	    git -C "${GITDIR}" commit -m "$(hostname).$(dnsdomainname) $(date +%Y-%m-%d_%H.%M.%S) ${CMNT}" && \
		if [ "${GITPP}" -eq 1 ]; then git -C "${GITDIR}" push; fi;
    fi;
    echo "BAD: ""$BAD" "GOOD: ""$GOOD"
  fi;
}
  fi;
fi;

  if [ "${INTERACT}" -eq 1 ]; then invoke_main & spinner $!; fi;
  if [ "${INTERACT}" -eq 0 ]; then invoke_main; fi;

exit ${RS};
