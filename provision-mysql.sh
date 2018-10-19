#!/bin/bash

mysql=( mysql )

echo "Running SQL Provisioner..."

# REF:  Borrowed and adapted from MySQL Docker Image:  https://github.com/docker-library/mysql/blob/master/5.7/docker-entrypoint.sh
# usage: process_init_file FILENAME MYSQLCOMMAND...
#    ie: process_init_file foo.sh mysql -uroot
# (process a single initializer file, based on its extension. we define this
# function here, so that initializer scripts (*.sh) can use the same logic,
# potentially recursively, or override the logic used in subsequent calls)
process_init_file() {
	local f="$1"; shift
	local mysql=( "$@" )

	case "$f" in
		*.sh)     echo "$0: running $f"; . "$f" ;;
		*.sql)    echo -n "$0: running $f"; "${mysql[@]}" < "$f"; ;;
		*.sql.gz) echo -n "$0: running $f"; gunzip -c "$f" | "${mysql[@]}" ; ;;
		*)        echo "$0: ignoring $f" ;;
	esac
	echo
}

# Run any SQL files in the sql-init folder
for f in /vagrant/sql-init/*; do
	process_init_file "$f" "${mysql[@]}"
done