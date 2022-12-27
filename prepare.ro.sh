type="pareto"
sysbench oltp_read_only --tables=20 --table_size=1000000 --threads=40 --mysql-host=127.0.0.1 --mysql-user=root --max-requests=0 --report-interval=1  --mysql-db=sbtest --mysql-ssl=off  --rand-type=$type prepare
