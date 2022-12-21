#MYSQLDIR=

set -x
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

startmysql(){
  sync
  sysctl -q -w vm.drop_caches=3
  echo 3 > /proc/sys/vm/drop_caches
  ulimit -n 1000000
  systemctl set-environment MYSQLD_OPTS="$1"
  systemctl start mysql-cd
}

shutdownmysql(){
  echo "Shutting mysqld down..."
  systemctl stop mysql-cd
  systemctl set-environment MYSQLD_OPTS=""
}

waitmysql(){
        set +e

        while true;
        do
                ${MYSQLDIR}mysql -h127.0.0.1 -Bse "SELECT 1" mysql

                if [ "$?" -eq 0 ]
                then
                        break
                fi

                sleep 30

                echo -n "."
        done
        set -e
}

initialstat(){
  cp $CONFIG $OUTDIR
  cp $0 $OUTDIR
}

collect_mysql_stats(){
  ${MYSQLDIR}mysqladmin ext -i10 > $OUTDIR/mysqladminext.txt &
  PIDMYSQLSTAT=$!
}
collect_dstat_stats(){
  vmstat 1 > $OUTDIR/vmstat.out &
  PIDDSTATSTAT=$!
}



shutdownmysql

RUNDIR=res-oltp-`hostname`-`date +%F-%H-%M`


#buffer_pool: 25
#randtype: uniform
#io_capacity: 15000
#storage: NVMe


BP=10
threads="1 2 4 8 16 32"
randtype="uniform"

for io in 5000
do

#echo "Restoring backup"
#rm -fr $DATADIR
#cp -r $BACKUPDIR $DATADIR
#chown mysql.mysql -R $DATADIR

iomax=$(( 3*$io/2 ))


# perform warmup
#./tpcc.lua --mysql-host=127.0.0.1 --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest --time=3600 --threads=56 --report-interval=1 --tables=10 --scale=100 --use_fk=1 run |  tee -a $OUTDIR/res.txt
        sysbench oltp_read_only --threads=20 --time=600 --tables=20 --table_size=1000000 --mysql-host=127.0.0.1 --mysql-user=root --max-requests=0 --report-interval=1 --mysql-db=sbtest --mysql-ssl=off  --rand-type=$randtype --mysql-password=zU7KaOUlGEivKdIVyAr run

for i in $threads
do

runid="io$io.BP${BP}.threads${i}"

        OUTDIR=$RUNDIR/$runid
        mkdir -p $OUTDIR

echo "server: ps8"              >> $OUTDIR/params.txt
echo "buffer_pool: $BP"         >> $OUTDIR/params.txt
echo "randtype: $randtype"      >> $OUTDIR/params.txt
echo "io_capacity: $io"         >> $OUTDIR/params.txt
echo "threads: $i"              >> $OUTDIR/params.txt
echo "storage: NVMe"            >> $OUTDIR/params.txt
echo "host: `hostname`"         >> $OUTDIR/params.txt

        # start stats collection


        time=300
        sysbench oltp_read_only --threads=$i --time=$time --tables=20 --table_size=1000000 --mysql-host=127.0.0.1 --mysql-user=root --max-requests=0 --report-interval=1 --mysql-db=sbtest --mysql-ssl=off  --rand-type=$randtype  --mysql-password=zU7KaOUlGEivKdIVyAr run |  tee -a $OUTDIR/results.txt
#        /mnt/data/vadim/bench/sysbench-tpcc/tpcc.lua --mysql-host=127.0.0.1 --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest --time=$time --threads=$i --report-interval=1 --tables=10 --scale=100 --use_fk=0 --report-csv=yes run |  tee -a $OUTDIR/res.thr${i}.txt


        sleep 30
done


done
