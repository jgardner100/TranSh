#!/bin/bash
#
# ./email.my - Remove any email addresses
#
# Author: John Gardner
# Date: 31 August 2010
#
#do_init

BLAST_VALUE="nobody@localhost.com"
G_TYPE="email"
NOLOG="true"
SITESCOPE_RES=""
COUNT_THRES=2
G_FND=0

#
# See if a column is listed
#
table_in() {
	typeset P_COL="$1"
	typeset P_LIST="$2"


	G_FND=0
	for LCOL in $P_LIST
	do
		if [ "$LCOL" = "$P_COL" ]; then
			G_FND=1
		fi
	done
}

# See if a table is listed
#
database_in() {
	typeset P_TABLE="$1"
	typeset P_DB="$2"
	typeset P_LIST="$3"


	typeset LTAB
	typeset LTAB_DB
	typeset LTAB_TAB


	G_FND=0
	for LTAB in $P_LIST
	do
		LTAB_DB=$(echo $LTAB|cut -d. -f1)
		LTAB_TAB=$(echo $LTAB|cut -d. -f2)

		if [ "$LTAB_TAB" = "$P_TABLE" -a "$LTAB_DB" = "$P_DB" ]; then
			G_FND=1
		fi
	done
}

#
# Simple dump transaction log if you can
#
dump_tran() {
	typeset P_DB="$1"


	do_verbose "Dump tran for $P_DB"
	do_isql "$P_DB" "dump tran $P_DB with truncate_only"
	if [ "$?" -ne 0 ]; then
		echo "Failed to dump tran in $P_DB"
		#             display( "$RES");
	fi
}

#
# Count the distinct email addresses in a field
#
count_samp() {
	typeset P_OWNER="$1"
	typeset P_DATABASE="$2"
	typeset P_TABLE="$3"
	typeset P_COL="$4"


	typeset RES
	typeset COUNT

	typeset -i RET


	do_verbose "TABLE=$P_OWNER.$P_TABLE COL=$P_COL (in $P_DATABASE)"

	do_isql "$P_DATABASE" "
			select count( distinct ${P_COL})
                        from $P_OWNER.$P_TABLE
			where ${P_COL} is not null
			and ${P_COL} not like 'TST_%'
			and ${P_COL} not like 'TEST_%'
	"
	#			and ${P_COL} != 'bfsmascashtestemail@macquarie.com'
	RET="$?"
	#echo "DEBUG: RES= $RES";
	RES=$(echo $RES|cut -d":" -f3-)
	#checkret "$RET" "Select count $P_OWNER.$P_COL from $P_TABLE failed!";
	if [ "$RET" -ne 0 ]; then
		do_verbose "$P_OWNER.$P_TABLE can't read (${RET}) ${RES}"
	elif [ "$RES" -le "$COUNT_THRES" ]; then
		do_verbose "$P_OWNER.$P_TABLE is ok $(date)"
	else
		COUNT=$(echo $RES)
		echo "$P_OWNER.$P_TABLE field $P_COL has email addresses (count=$COUNT)!!!"
		do_verbose "$RES"
		SITESCOPE_RES="error"
	fi
}

#
# Show the first three entries from the email column
#
dump_samp() {
	typeset P_OWNER="$1"
	typeset P_DATABASE="$2"
	typeset P_TABLE="$3"
	typeset P_COL="$4"


	echo "TABLE=$P_OWNER.$P_TABLE COL=$P_COL"

	do_isql "$P_DATABASE" "
			set rowcount 3
go
			select distinct ':'+convert(varchar(70),${P_COL})+':'
                        from $P_OWNER.$P_TABLE
			where ${P_COL} != null
			and ${P_COL} != ' '
	"
	checkret "$?" "Select $P_OWNER.$P_COL from table $P_TABLE failed!" "nolog"
	display "$RES"
	echo
}

#
# Get the list of column names that contain the string "email" in the column name
#
get_col_list() {
	typeset M_OWNER="$1"
	typeset M_DATABASE="$2"
	typeset M_TABLE="$3"


	typeset RES


	do_verbose "** Getting columns in M_OWNER=|$M_OWNER| M_DATABASE=|$M_DATABASE| M_TABLE=|$M_TABLE| G_TYPE=|${G_TYPE}|"

	do_isql "$M_DATABASE" "
		SELECT DISTINCT
			'::'+
			convert(varchar(32),c.name)+':'+
			convert(varchar(32),t.name)+':'
		FROM 
			dbo.sysobjects    o
			,dbo.syscolumns    c
			,dbo.systypes      t
		WHERE 
			o.name = '$M_TABLE'
			AND user_name(o.uid) = '$M_OWNER'
			AND c.id        = o.id
			AND c.usertype *= t.usertype
			AND c.name like '%${G_TYPE}%'
			AND c.length > 5
			AND t.name in ( 'char', 'varchar')
			AND c.name not like '%date%'
			AND c.name not like '%email_type%'
		ORDER BY
			c.name"
	checkret "$?" "Select column details failed for $M_TABLE" "true"
	RES=$(echo $RES | cut -d ":" -f3)
}

#
# Dump a sample from all the emails columns in a table
#
dump_samp_all() {
	typeset P_OWNER="$1"
	typeset P_DATABASE="$2"
	typeset P_TABLE="$3"


	typeset COLITEM
	typeset COL


	get_col_list "$P_OWNER" "$P_DATABASE" "$P_TABLE"

	do_verbose "dump_samp_all: got col list of |$RES|"

	for COLITEM in $RES
	do
		COL=$(echo $COLITEM|cut -d: -f2)
		COL=$(echo $COL)

		do_verbose "COL= $COL COLITEM=$COLITEM"

		if [ -z "$COL"  ]; then
			echo "DEBUG: got blank string"
		else
			table_in "$COL" "$EMAIL_SKIP"

			if [ $G_FND -ne 0 ]; then
				echo "Skip $P_OWNER.$P_TABLE field $COL"
			elif [ ! -z "$SITESCOPE_FLAG" ]; then
				count_samp "$P_OWNER" "$P_DATABASE" "$P_TABLE" "$COL"
			else
				dump_samp "$P_OWNER" "$P_DATABASE" "$P_TABLE" "$COL"
			fi
		fi
	done
}

#
# Show all the select strings needed to look at the email columns (so they can cut and paste)
#
dump_select() {
	typeset P_OWNER="$1"
	typeset P_DATABASE="$2"
	typeset P_TABLE="$3"


	typeset COL


	get_col_list "$P_OWNER" "$P_DATABASE" "$P_TABLE"

	if [ ! -z "$RES" ]; then

		typeset -i COUNT=0 
		echo_noline "select "
		for COLITEM in $RES
		do
			COL=$(echo $COLITEM|cut -d: -f2)
			if [ "$COUNT" = 0 ]; then
				echo_noline "$COL"
			else
				echo_noline ",$COL"
			fi
			COUNT=$(expr $COUNT + 1)
		done
		echo
		echo "from $P_OWNER.$P_TABLE"
		echo
	fi
}

dump_table() {
	typeset P_OWNER="$1"
	typeset P_DATABASE="$2"
	typeset P_TABLE="$3"


	typeset COL
	typeset TYPE
	typeset LEN


	echo "Dumping tables $P_OWNER	$P_DATABASE	$P_TABLE"
	do_isql "$P_DATABASE" "
		SELECT DISTINCT
			':'+
			convert(varchar(32),c.name)+':'+
			convert(varchar(32),t.name)+':'+
			convert(varchar(4),c.length)+':'+
			convert(varchar(4),c.prec)+':'+
			convert(varchar(4),c.scale)+':'
		FROM 
			dbo.sysobjects    o
			,dbo.syscolumns    c
			,dbo.systypes      t
			,dbo.sysprocedures d
			,dbo.sysprocedures r
		WHERE 
			o.name = '$P_TABLE'
			AND user_name(o.uid) = '$P_OWNER'
			AND c.id        = o.id
			AND c.usertype *= t.usertype
			AND c.cdefault *= d.id
			AND c.domain   *= r.id
		ORDER BY
			c.name
	"
	checkret "$?" "Select column details failed for $P_TABLE" "true"

	#echo "DEBUG: RES = " $RES;
	rm -f "/tmp/mfile.txt"
	outfile "/tmp/mfile.txt" "$RES"

	typeset -i COUNT=0 
	echo "Create table $P_OWNER.$P_TABLE ("
	cat "/tmp/mfile.txt" | 	while read LINE
	do
		if [ "$COUNT" -ne 0 ]; then
			echo_noline "  , "
		else
			echo_noline "  ( "
		fi

		COL=$(echo $LINE|cut -d: -f2)
		TYPE=$(echo $LINE|cut -d: -f3)

		if [ "$TYPE" = "char" -o "$TYPE" = "varchar" ]; then
			LEN=$(echo $LINE|cut -d: -f4)
			echo "$COL $TYPE($LEN)"
		elif [ "$TYPE" = "decimal" ]; then
			echo "$COL numeric"
		else
			echo "$COL $TYPE"
		fi
		COUNT=$(expr $COUNT + 1)
	done
	echo ")"
}

#
# Change email addresses by adding a prefix
#
blast_addvalue() {
	typeset P_OWNER="$1"
	typeset P_DB="$2"
	typeset P_TABLE="$3"
	typeset P_FIELD="$4"


	table_in "$P_FIELD" "$EMAIL_SKIP"

	if [ $G_FND -ne 0 ]; then
		echo "** Skip $P_OWNER.$P_TABLE field $COL **"
	else
		do_isql "$P_DB" "
			UPDATE
				$P_OWNER.$P_TABLE 
			SET
				$P_FIELD='TST_'+$P_FIELD
			WHERE
				$P_FIELD != null
				and $P_FIELD not like 'TST_%'
go
			select @@rowcount
go
		"
		if [ "$?" -ne 0 ]; then
			echo "Failed to update $P_FIELD on ${P_OWNER}.${P_TABLE} in database ${P_DB}!"
			display "$RES"
		else
			echo "$P_FIELD ${P_OWNER}.${P_TABLE} updated"
			echo_noline "Rows updated="
			display "$RES"
		fi
	fi
}

#
# Change email addresses by overwritting with a value
#
blast_field_all() {
	typeset P_OWNER="$1"
	typeset P_DB="$2"
	typeset P_TABLE="$3"
	typeset P_FIELD="$4"


	do_verbose "blast field all owner=$P_OWNER db=$P_DB table=$P_TABLE field=$P_FIELD"
	do_isql "$P_DB" "
		UPDATE
			$P_OWNER.$P_TABLE 
		SET
			$FIELD='$BLAST_VALUE'
		WHERE
			$P_FIELD != null
			and $P_FIELD != '$BLAST_VALUE'
go
		select @@rowcount
go
	"
	if [ "$?" -ne 0 ]; then
		echo "Failed to update $P_FIELD on ${P_OWNER}.${P_TABLE} in database ${P_DB}!"
		display "$RES"
	else
		echo "$P_FIELD ${P_OWNER}.${P_TABLE} updated"
		echo_noline "Rows updated="
		display "$RES"
	fi
}

#
# Change email addresses by overwritting with a value one chunk at a time
# allows for small transaction logs
#
blast_field_chunk() {
	typeset P_OWNER="$1"
	typeset P_DB="$2"
	typeset P_TABLE="$3"
	typeset P_FIELD="$4"


	typeset -i ROWCOUNT=1 

	while [ "$ROWCOUNT" -gt 0 ]
	do

		dump_tran "$P_DB"

		do_isql "$P_DB" "
                        set rowcount 100000
go
                        UPDATE
                                $P_OWNER.$P_TABLE
                        SET
                                $FIELD='$BLAST_VALUE'
                        WHERE
                                $P_FIELD != null
                                and $P_FIELD != '$BLAST_VALUE'
go
                        SELECT
                                count($P_FIELD) from $P_OWNER.$P_TABLE
                        WHERE
                                $P_FIELD != null
                                and $P_FIELD != '$BLAST_VALUE'
go
                "
		if [ "$?" -ne 0 ]; then
			echo "Failed to update $P_FIELD on ${P_OWNER}.${P_TABLE} in database ${P_DB}!"
			display "$RES"
			ROWCOUNT=0
		else
			ROWCOUNT=$RES
			echo "$P_FIELD ${P_OWNER}.${P_TABLE} updated"
			echo_noline "Rows updated="
			display "$ROWCOUNT"
		fi
	done
	echo "finished"
}

#
# Update all the values in the email column for a table
#
blast_table() {
	typeset P_OWNER="$1"
	typeset P_DB="$2"
	typeset P_TABLE="$3"


	typeset FIELD_LIST
	typeset FIELD


	get_col_list "$P_OWNER" "$P_DB" "$P_TABLE"
	FIELD_LIST="$RES"

	do_verbose "Trying to blast $P_DB $P_TABLE owner=$P_OWNER"

	do_isql "$P_DB" "alter table $P_TABLE disable trigger"
	checkret "$?" "disable $DBUSER $P_DB $P_TABLE triggers failed!" "nolog"

	for FNAME in $FIELD_LIST
	do
		FIELD=$(echo $FNAME|cut -d: -f2)

		table_in "$FIELD" "$EMAIL_SKIP"

		if [ $G_FND -ne 0 ]; then
			echo "!! Skip $P_OWNER.$P_TABLE field $COL !!"
		else

			database_in "$P_TABLE" "$P_DB" "$PREFIX_EMAIL"
			do_verbose "DEBUG: G_FND=$G_FND"

			if [ $G_FND -ne 0 ]; then
				blast_addvalue "$P_OWNER" "$P_DB" "$P_TABLE" "$FIELD"
			else
				if [ -z "$UPDATE_FLAG" ]; then
					if [ -z "$CHUNK_FLAG" ]; then
						blast_field_all "$P_OWNER" "$P_DB" "$P_TABLE" "$FIELD"
					else
						blast_field_chunk "$P_OWNER" "$P_DB" "$P_TABLE" "$FIELD"
					fi
				else
					blast_addvalue "$P_OWNER" "$P_DB" "$P_TABLE" "$FIELD"
				fi

				do_isql "$P_DB" "select count(distinct $FIELD)
				from $P_OWNER.$P_TABLE
				where $FIELD != null
				and $FIELD not like 'TST_%'"
				if [ "$?" -ne 0 ]; then
					echo "Failed to select count of $FIELD"
				else
					if [ "$RES" -gt 1 ]; then
						echo "Error $FIELD in $P_TABLE not updated!"
						display "Count check=$RES"
					else
						do_verbose $RES
					fi
				fi
			fi

		fi
	done

	do_isql "$P_DB" "alter table $P_TABLE enable trigger"
	checkret "$?" "enable $DBUSER $P_DB $P_TABLE triggers failed!"
}

dump_all() {
	typeset P_DATABASE="$1"


	typeset LIST
	typeset OWNER
	typeset TABLE

	typeset -i RETVAL


	do_verbose "starting dump_all of |$P_DATABASE|"
	if [ ! -z "$BLAST_FLAG" ]; then
		echo "Removing email addresses for db $P_DATABASE"
	else
		echo "Database = $P_DATABASE"
	fi

	do_isql "$P_DATABASE" "
		SELECT DISTINCT
		        user_name(o.uid)+':'+o.name
		FROM
		        dbo.sysobjects o
		        ,dbo.syscolumns c
		WHERE
			c.id = o.id
			AND c.name like '%email%'
			AND c.length > 5
			AND c.name not like '%date%'
			AND c.name not like '%email_type%'
			AND o.type = 'U'
		ORDER BY
		        o.name
	"
	RETVAL="$?"
	checkret "$RETVAL" "Can not select table names" "nolog"

	LIST=$(echo $RES)
	do_verbose "dump_all: from list is - LIST = |$LIST|"

	if [ $RETVAL -eq 0 ]; then
		for ITEM in $LIST
		do
			do_verbose "process $ITEM"
			OWNER=$(echo $ITEM|cut -d: -f1)
			TABLE=$(echo $ITEM|cut -d: -f2)

			if [ ! -z "$LIST_FLAG" ]; then
				do_verbose "dump_select $OWNER.$TABLE"
				dump_select "$OWNER" "$P_DATABASE" "$TABLE"
			elif [ ! -z "$BLAST_FLAG" ]; then
				do_verbose "blast_table $OWNER.$TABLE"
				blast_table "$OWNER" "$P_DATABASE" "$TABLE"
			elif [ ! -z "$SAMP_FLAG" ]; then
				do_verbose "dump_samp_all $OWNER.$TABLE"
				dump_samp_all "$OWNER" $P_DATABASE $TABLE
			elif [ ! -z "$SITESCOPE_FLAG" ]; then
				do_verbose "dump_samp_all $OWNER.$TABLE"
				dump_samp_all "$OWNER" $P_DATABASE $TABLE
			else
				do_verbose "dump_table $OWNER.$TABLE"
				dump_table "$OWNER" "$P_DATABASE" "$TABLE"
			fi
		done
	else
		echo "no db list to process, user=$DBUSER"
	fi
	do_verbose "finishing  dump_all of |$P_DATABASE|"
}

usage() {


	typeset NAME


	NAME=$(basename $1)
	echo "usage: $NAME [-e env][-u user][-c threshold][-d database name][-m mailaddr][-t string][-b][-l][-s][-x][-z][-k][-v] dataserver [database*]"
	echo ""
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -u = database user to login as"
	echo " -d = list of databases to run against"
	echo " -c = threshold of unique addresses to be error"
	echo " -v = verbose output"
	echo " -m = email addr to write over old values"
	echo " -b = overwrite all non null email columns entries"
	echo " -l = list selects to query all email columns"
	echo " -s = dump a sample from each table"
	echo " -t = string in column name to search for (default=email)"
	echo " -x = give output for Sitescope monitoring"
	echo " -z = add TST to address rather than overwrite"
	echo " -k = process rows in subsets to allow for small transaction logs"
	echo ""

	exit 1
}

set -- `getopt c:u:e:lbsd:m:t:xvzk $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -c)           COUNT_THRES=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        -e)           USE_ENV=$2; shift 2;;
        -l)           LIST_FLAG=$i; shift;;
        -b)           BLAST_FLAG=$i; shift;;
        -s)           SAMP_FLAG=$i; shift;;
        -d)           DATABASE_ARG=$2; shift 2;;
        -m)           BLAST_VALUE=$2; shift 2;;
        -t)           G_TYPE=$2; shift 2;;
        -x)           SITESCOPE_FLAG=$i; shift;;
        -v)           VERBOSE=$i; shift;;
        -z)           BLAST_FLAG=$i; shift;;
        -k)           CHUNK_FLAG=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -lt 1 ]; then
	echo "value=$#"
	usage $0
fi

setdb $1 $USE_USER

if [ ! -z "$DATABASE_ARG" ]; then
	echo dump_all $DB
	dump_all $DATABASE_ARG
elif [ "$#" -eq 1 ]; then
	get_envfile $TMPENV

	for DB in $DB_LIST
	do
		dump_all $DB
	done

	rm -f $TMPENV
else
	shift
	for DB in $*
	do
		dump_all $DB
	done
fi

if [ ! -z "$SITESCOPE_FLAG" ]; then
	if [ ! -z "$SITESCOPE_RES" ]; then
		echo "Return Code: 1"
		exit 1
	else
		echo "Return Code: 0"
		exit 0
	fi
fi

rm -f $TMPENV

exit 0

#
