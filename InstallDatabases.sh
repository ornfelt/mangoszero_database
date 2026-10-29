#!/bin/sh
##############################################################################
# This utility assist you in setting up your mangos database.                #
# This is a port of InstallDatabases.bat written by Antz for Windows         #
#                                                                            #
##############################################################################

OLDRELEASE="Rel21"
RELEASE="Rel22"
DUMP="NO"

dbname=""
dbcommand=""

createcharDB="YES"
createworldDB="YES"
createrealmDB="YES"

loadcharDB="YES"
loadworldDB="YES"
loadrealmDB="YES"
dbType="POPULATED"

updatecharDB="YES"
updateworldDB="YES"
updaterealmDB="YES"

addRealmList="YES"

svr_def="localhost"
user_def="mangoszero"
pass_def="mangoszero"
port_def="3306"
wdb_def="mangos0"
cdb_def="character0"
rdb_def="realmd"

printHelp()
{
	printf "Usage: $0 [-s] [-u] [-d] [-h]\n"
	printf "\t-s: Run this script in silent mode, only prompt for the database information\n"
	printf "\t-u: Run only the updates of the database\n"
	printf "\t-d: Dump the database configuration into the home directory of the user\n"
	printf "\t-h: Display this help\n"
}

printBanner()
{
	clear
	printf " #     #     #    #   #  ###   ###   ####  \n"
	printf " ##   ##    # #   ##  # #     #   # #      \n"
	printf " # # # #   #   #  # # # # ### #   #  ###   \n"
	printf " #  #  #  ####### #  ## #   # #   #     #  \n"
	printf " #     #  #     # #   #  ###   ###  ####   \n"
	printf "\n"
	printf " Database Setup and World Loader v0.03 	\n"
	printf " ---------------------------------------------- \n"
	printf "  Website / Forum / Wiki : https://getmangos.eu \n"
	printf " ---------------------------------------------- \n"
	printf "\n"
	printf "\n"
}

printActivities()
{
	printf "\tCharacter Database : \tV - Toggle Create DB (${createcharDB})	\n"
	printf "\t\t\t\tC - Toggle Create Structure (${loadcharDB}) \n"
	printf "\t\t\t\tB - Apply Character DB updates (${updatecharDB})\n"
	printf "\n"
	printf "\t    World Database : \tE - Toggle Create DB (${createworldDB}) \n"
	printf "\t\t\t\tW - Toggle Create Structure (${loadworldDB}) \n"	
	if [ "${loadworldDB}" = "YES" ]; then
		printf "\t\t\t\tD - Toggle World Type (${dbType})\n"
	fi
	printf "\t\t\t\tU - Apply World DB updates (${updateworldDB})\n"
	printf "\n"
	printf "\t    Realm Database : \tT - Toggle Create DB (${createrealmDB})\n"
	printf "\t\t\t\tR - Toggle Create Structure (${loadrealmDB})\n"
	printf "\t\t\t\tY - Apply Realm DB updates (${updaterealmDB})\n"
	printf "\t\t\t\tL - Toggle Add RealmList Entry (${addRealmList})\n"	
	printf "\n"
	printf "\t\t\t\tN - Next Step\n"
	printf "\t\t\t\tX - Exit\n"
}

determineDBName()
{
	if [ $(which mariadb) ]; then
		printf "MariaDB found.\n"
		dbname="MariaDB"
	elif [ $(which mysql) ]; then
		printf "MySQL found.\n"
		dbname="MySQL"
	else
		printf "Did not find mariadb or mysql.\n"
		exit 1
	fi
}

readPassword()
{
	# No echo when typed; read plainly when the answers are piped in.
	if [ -t 0 ]; then
		stty -echo
		read pass
		stty echo
		printf "\n"
	else
		read pass
	fi
}

determineDBCommand()
{
	# The connection goes in an option file only this user can read, removed on exit,
	# so the password is neither on the command line nor stored by mysql_config_editor.
	dbconf=$(mktemp)
	trap 'rm -f "${dbconf}"' EXIT
	trap 'exit 1' INT TERM
	chmod 600 "${dbconf}"
	escaped_pass=$(printf "%s" "${pass}" | sed 's/\\/\\\\/g; s/"/\\"/g')
	printf "[client]\nhost=%s\nport=%s\nuser=%s\npassword=\"%s\"\n" "${svr}" "${port}" "${user}" "${escaped_pass}" > "${dbconf}"

	if [ $dbname = "MariaDB" ]; then
		dbcommand="mariadb --defaults-extra-file=${dbconf} -q -s"
	elif [ $dbname = "MySQL" ]; then
		dbcommand="mysql --defaults-extra-file=${dbconf} -q -s"
	else
		printf "Did not find mariadb or mysql.\n"
	fi
}

# runSql <database> <sql file>
# The update files create their procedure as DEFINER=`root`@`localhost`, which only a
# SUPER / SET_ANY_DEFINER account may do; without the clause the procedure belongs to the
# connecting user. An update procedure swallows its sql errors and reports
# '* UPDATE FAILED *' instead, so that output counts as a failure too.
runSql()
{
	output=$(sed 's/DEFINER=`[^`]*`@`[^`]*`//g' "$2" | ${dbcommand} "$1" 2>&1)
	status=$?
	if [ -n "${output}" ]; then
		printf "%s\n" "${output}"
	fi
	if [ ${status} -ne 0 ]; then
		return 1
	fi
	case "${output}" in
		*"UPDATE FAILED"*) return 1;;
	esac
	return 0
}

# runSqlDir <database> <dir> <verb>   every .sql in the dir, sorted; a missing dir is skipped
runSqlDir()
{
	for file in "$2"/*.sql
	do
		[ -e "${file}" ] || continue
		printf "$3 ${file}\n"
		runSql "$1" "${file}" || return 1
		printf "File ${file} imported\n"
	done
}

createCharDB()
{
	printf "Creating Character database ${cdb}\n"
	${dbcommand} -e "CREATE DATABASE IF NOT EXISTS \`${cdb}\`" || return 1

	if [ "${loadcharDB}" = "YES" ]; then
		loadCharDB || return 1
	fi
}

loadCharDB()
{
	printf "Loading data into character database ${cdb}\n"
	runSql "${cdb}" Character/Setup/characterLoadDB.sql
}

updateCharDB()
{
	printf "Updating data into the character database ${cdb}\n"
	runSqlDir "${cdb}" Character/Updates/${OLDRELEASE} "Applying update" || return 1
	runSqlDir "${cdb}" Character/Updates/${RELEASE} "Applying update"
}

createWorldDB()
{
	printf "Creating World database ${wdb}\n"
	${dbcommand} -e "CREATE DATABASE IF NOT EXISTS \`${wdb}\`" || return 1

	if [ "${loadworldDB}" = "YES" ]; then
		loadWorldDB || return 1
	fi
}

loadWorldDB()
{
	printf "Loading data into world database ${wdb}\n"
	runSql "${wdb}" World/Setup/mangosdLoadDB.sql || return 1

	if [ "${dbType}" = "POPULATED" ]; then
		populateWorldDB || return 1
	fi
}

populateWorldDB()
{
	printf "Importing World database ${wdb}\n"
	runSqlDir "${wdb}" World/Setup/FullDB/${OLDRELEASE} "Importing file" || return 1
	runSqlDir "${wdb}" World/Setup/FullDB "Importing file"
}

updateWorldDB()
{
    printf "Updating data into the World database ${wdb}\n"
    runSqlDir "${wdb}" World/Updates/${OLDRELEASE} "Applying update" || return 1
    runSqlDir "${wdb}" World/Updates/${RELEASE} "Applying update"
}

createRealmDB()
{
	printf "Creating realm database ${rdb}\n"
	${dbcommand} -e "CREATE DATABASE IF NOT EXISTS \`${rdb}\`" || return 1

	if [ "${loadrealmDB}" = "YES" ]; then
		loadRealmDB || return 1
	fi
}

loadRealmDB()
{
	printf "Loading data into realm database ${rdb}\n"	
	runSql "${rdb}" Realm/Setup/realmdLoadDB.sql
}

updateRealmDB()
{
	printf "Updating data into the Realm database ${rdb}\n"
	runSqlDir "${rdb}" Realm/Updates/${OLDRELEASE} "Applying update" || return 1
	runSqlDir "${rdb}" Realm/Updates/${RELEASE} "Applying update"
}

addRealmList()
{
	printf "Adding realm list entries\n"
	runSql "${rdb}" Tools/updateRealm.sql
}

activity=""

while getopts "suhd" o; do
	case "${o}" in
		s)
			activity="N"
			printf "You selected silent mode\n"
			;;
		u)
			createcharDB="NO"
			createworldDB="NO"
			createrealmDB="NO"

			loadcharDB="NO"
			loadworldDB="NO"
			loadrealmDB="NO"
			dbType="EMPTY"
			addRealmList="NO"
			printf "You selected update only\n"
			;;
		d)
			DUMP="YES"
			;;
		h)
			printHelp
			exit 0
			;;
	esac
done

while [ -z "${activity}" ] || [ "${activity}" != "N" ]
do
	printBanner
	printActivities
	printf "Please select an activity : "
	read activity
	activity=$(echo ${activity} | tr '[:lower:]' '[:upper:]' )
	case ${activity} in
		"V")
			if [ "${createcharDB}" = "YES" ]; then
				createcharDB="NO"
			else 
				createcharDB="YES"
			fi
			;;
		"C")
			if [ "${loadcharDB}" = "YES" ]; then
				loadcharDB="NO"
			else 
				loadcharDB="YES"
			fi
			;;
		"B")
			if [ "${updatecharDB}" = "YES" ]; then
				updatecharDB="NO"
			else 
				updatecharDB="YES"
			fi
			;;
		"E")
			if [ "${createworldDB}" = "YES" ]; then
				createworldDB="NO"
			else 
				createworldDB="YES"
			fi	
			;;
		"W")
			if [ "${loadworldDB}" = "YES" ]; then
				loadworldDB="NO"
			else 
				loadworldDB="YES"
			fi	
			;;
		"D")
			if [ "${dbType}" = "POPULATED" ]; then
				dbType="EMPTY"
			else 
				dbType="POPULATED"
			fi 				
			;;
		"U")
			if [ "${updateworldDB}" = "YES" ]; then
				updateworldDB="NO"
			else 
				updateworldDB="YES"
			fi
			;;
		"T")
			if [ "${createrealmDB}" = "YES" ]; then
				createrealmDB="NO"
			else 
				createrealmDB="YES"
			fi 				
			;;
		"R")
			if [ "${loadrealmDB}" = "YES" ]; then
				loadrealmDB="NO"			
			else 
				loadrealmDB="YES"
			fi
			;;
		"Y")
			if [ "${updaterealmDB}" = "YES" ]; then
				updaterealmDB="NO"
			else 
				updaterealmDB="YES"
			fi
			;;
		"L")
			if [ "${addRealmList}" = "YES" ]; then
				addRealmList="NO"
			else 
				addRealmList="YES"
			fi
			;;
		"N")
			;;
		"X")
			exit 0;;
		*)
			printf "Invalid selection";;
	esac
done

printBanner
determineDBName
printf "What is your ${dbname} host name ?\t[${svr_def}]: "
read svr
svr=${svr:-${svr_def}}
printf "What is your ${dbname} user name ?\t[${user_def}]: "
read user
user=${user:-${user_def}}
printf "What is your ${dbname} port ?\t[${port_def}]: "
read port
port=${port:-${port_def}}
printf "What is your ${dbname} password ?\t[]: "
readPassword
pass=${pass:-${pass_def}}
determineDBCommand

if [ "${createcharDB}" = "YES" ] || [ "${loadcharDB}" = "YES" ] || [ "${updatecharDB}" = "YES" ]; then
	printf "What is your Character database name ?\t[${cdb_def}]: "
	read cdb
	cdb=${cdb:-${cdb_def}}
fi

if [ "${createworldDB}" = "YES" ] || [ "${loadworldDB}" = "YES" ] || [ "${updateworldDB}" = "YES" ]; then
	printf "What is your World database name ?\t[${wdb_def}]: "
	read wdb
	wdb=${wdb:-${wdb_def}}
fi

if [ "${createrealmDB}" = "YES" ] || [ "${loadrealmDB}" = "YES" ] || [ "${updaterealmDB}" = "YES" ] || [ "${addRealmList}" = "YES" ]; then
	printf "What is your Realm database name ?\t[${rdb_def}]: "
	read rdb
	rdb=${rdb:-${rdb_def}}
fi

if [ "${createcharDB}" = "YES" ]; then
	if ! createCharDB; then
		printf "Character database creation failed.\n"
		exit 1
	fi
fi

if [ "${createworldDB}" = "YES" ]; then
	if ! createWorldDB; then
		printf "World database creation failed.\n"
		exit 1
	fi
fi

if [ "${createrealmDB}" = "YES" ]; then
	if ! createRealmDB; then
		printf "Realm database creation failed.\n"
		exit 1
	fi
fi

if [ "${updatecharDB}" = "YES" ]; then
	if ! updateCharDB; then
		printf "Character database update failed.\n"
		exit 1
	fi
fi

if [ "${updateworldDB}" = "YES" ]; then
	if ! updateWorldDB; then
		printf "World database update failed.\n"
		exit 1
	fi
fi

if [ "${updaterealmDB}" = "YES" ]; then
	if ! updateRealmDB; then
		printf "Realm database update failed.\n"
		exit 1
	fi
fi

if [ "${addRealmList}" = "YES" ]; then
	if ! addRealmList; then
		printf "Adding the realm list entry failed.\n"
		exit 1
	fi
fi

if [ "${DUMP}" = "YES" ]; then
	printf "Dumping database information...\n"
	echo "${svr};${port};${user};${pass};${rdb}" > ~/db.conf
	echo "${svr};${port};${user};${pass};${wdb}" >> ~/db.conf
	echo "${svr};${port};${user};${pass};${cdb}" >> ~/db.conf
fi

printBanner
printf "Database creation and load complete :-)\n"
printf "\n"
