#!/bin/bash

# -------------------------------
# MySQL 配置（请根据实际情况修改）
MYSQL_USER="root"
MYSQL_PASSWORD="123"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
# 默认数据库（用于部分命令）
MYSQL_DATABASE="mysql"
# 数据目录（用于超大库检查）
MYSQL_DATA_DIR="/oradata"
# 备份文件存放目录（请根据实际情况修改）
BACKUP_DIR="/backup/mysql"
# -------------------------------

# 输出文件
REPORT_FILE="mysql_system_report.log"

# 清空报告文件并写入标题
echo "MySQL & 操作系统巡检报告 - $(date)" > $REPORT_FILE
echo "=====================================" >> $REPORT_FILE

###############################################################################
#【1】操作系统基础信息（一级标题）
###############################################################################
echo "#【1】操作系统基础信息" >> $REPORT_FILE
echo "##1.1 主机名：$(hostname)" >> $REPORT_FILE
echo "##1.2 系统发行版：" >> $REPORT_FILE
cat /etc/redhat-release >> $REPORT_FILE
echo "##1.3 内核版本：" >> $REPORT_FILE
uname -r >> $REPORT_FILE
echo "##1.4 运行时间：" >> $REPORT_FILE
uptime >> $REPORT_FILE
echo "##1.5 服务器型号：" >> $REPORT_FILE
dmidecode | grep "Product Name" >> $REPORT_FILE 2>/dev/null
echo "##1.6 CPU 信息：" >> $REPORT_FILE
cat /proc/cpuinfo | grep 'model name' | uniq -c >> $REPORT_FILE
echo "##1.7 内存信息：" >> $REPORT_FILE
cat /proc/meminfo >> $REPORT_FILE
echo "##1.8 IP 地址及网络接口：" >> $REPORT_FILE
ip address >> $REPORT_FILE
echo "##1.9 操作系统版本：" >> $REPORT_FILE
lsb_release -a 2>/dev/null || cat /proc/version >> $REPORT_FILE
echo "" >> $REPORT_FILE

###############################################################################
#【2】性能检查（操作系统层面）
###############################################################################
echo "#【2】性能检查（操作系统层面）" >> $REPORT_FILE
echo "##2.1 CPU 占用率：" >> $REPORT_FILE
top -b -n1 | grep "Cpu(s)" >> $REPORT_FILE
echo "##2.2 内存使用情况 & Swap：" >> $REPORT_FILE
free -m >> $REPORT_FILE
echo "##2.3 磁盘 I/O 统计：" >> $REPORT_FILE
iostat -xkd 1 3 >> $REPORT_FILE
echo "##2.4 磁盘空间：" >> $REPORT_FILE
df -h >> $REPORT_FILE
echo "##2.5 系统开放端口（LISTEN 状态）：" >> $REPORT_FILE
netstat -an | grep LISTEN >> $REPORT_FILE
echo "##2.6 进程检查（系统进程）：" >> $REPORT_FILE
ps aux | more >> $REPORT_FILE
echo "##2.7 最近系统日志 (/var/log/messages)：" >> $REPORT_FILE
tail -n 20 /var/log/messages >> $REPORT_FILE
echo "" >> $REPORT_FILE

###############################################################################
#【3】数据库巡检（合并 MySQL 运行、Binlog、错误日志及其它检查）
###############################################################################
echo "#【3】数据库巡检" >> $REPORT_FILE

echo "##3.1 MySQL 运行状态：" >> $REPORT_FILE
systemctl is-active mysqld >> $REPORT_FILE

echo "##3.2 MySQL 并发连接及失败连接：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('Threads_running','Threads_created','Threads_cached','Aborted_clients','Aborted_connects');" >> $REPORT_FILE

echo "##3.3 MySQL Binlog 状态及相关配置：" >> $REPORT_FILE
BINLOG_STATUS=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW GLOBAL VARIABLES LIKE 'log_bin';" | awk 'NR==2 {print $2}')
if [[ "$BINLOG_STATUS" == "ON" ]]; then
    echo "Binlog 已启用" >> $REPORT_FILE
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D$MYSQL_DATABASE -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW MASTER STATUS;" >> $REPORT_FILE
    mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D$MYSQL_DATABASE -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW BINARY LOGS;" >> $REPORT_FILE
else
    echo "⚠️ MySQL 未启用 Binlog，跳过 Binlog 相关检查。" >> $REPORT_FILE
fi

echo "##3.4 MySQL 错误日志：" >> $REPORT_FILE
LOG_FILE=$(grep -i "log_error" /etc/my.cnf | awk -F'=' '{print $2}' | tr -d ' ')
if [[ -z "$LOG_FILE" ]]; then
    echo "未找到 MySQL 错误日志配置。" >> $REPORT_FILE
elif [[ ! -f "$LOG_FILE" ]]; then
    echo "MySQL 错误日志文件不存在：$LOG_FILE" >> $REPORT_FILE
elif [[ ! -s "$LOG_FILE" ]]; then
    echo "MySQL 错误日志为空，无错误记录。" >> $REPORT_FILE
else
    echo "##3.5 MySQL 错误日志（最近 20 行）：" >> $REPORT_FILE
    tail -n 20 "$LOG_FILE" >> $REPORT_FILE
fi

echo "##3.6 MySQL 进程检查：" >> $REPORT_FILE
ps -ef | grep mysqld | grep -v grep >> $REPORT_FILE

echo "##3.7 数据库版本：" >> $REPORT_FILE
db_version=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -sN -e "SELECT VERSION();")
echo "($db_version)" >> $REPORT_FILE

echo "##3.8 超大库检查（数据目录大小）：" >> $REPORT_FILE
du -sh ${MYSQL_DATA_DIR}/* 2>/dev/null >> $REPORT_FILE

echo "##3.9 超大表检查（SHOW TABLE STATUS;）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D$MYSQL_DATABASE -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW TABLE STATUS;" >> $REPORT_FILE

echo "##3.10 慢查询日志状态：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'slow_query_log%';" >> $REPORT_FILE

echo "##3.11 重要参数检查：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'back_log%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'max_allowed_packet%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'interactive_timeout%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'wait_timeout%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'skip_name_resolve%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'max_connections%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'log_bin%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'expire_logs_days%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'open_files_limit%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'table_open_cache%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'thread_cache_size%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'sort_buffer_size%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'join_buffer_size%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'innodb_file_per_table%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'innodb_open_files%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'innodb_thread_concurrency%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'innodb_log_buffer_size%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'innodb_log_file_size%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'innodb_log_files_in_group%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'general_log%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'slow_query_log%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'long_query_time%';" >> $REPORT_FILE

echo "##3.11 QPS 检查（查询总数）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Queries';" >> $REPORT_FILE

echo "##3.12 读写比检查（com_select, com_insert, com_update, com_delete）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Com_%';" >> $REPORT_FILE

echo "##3.13 当前连接数（Threads_connected）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Threads_connected';" >> $REPORT_FILE

echo "##3.14 最大连接数（Max_used_connections 与 max_connections）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Max_used_connections';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE 'max_connections%';" >> $REPORT_FILE

echo "##3.15 异常连接查询（Aborted_clients, Aborted_connects）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Aborted_%';" >> $REPORT_FILE

echo "##3.16 并发线程查询（Threads_running）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW GLOBAL STATUS LIKE 'Threads_running';" >> $REPORT_FILE

echo "##3.17 线程缓存池检查（Threads_created 与 Connections）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Threads_created';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Connections';" >> $REPORT_FILE

echo "##3.18 运行线程状态查询（完整进程列表）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW FULL PROCESSLIST;" >> $REPORT_FILE

echo "##3.19 InnoDB Buffer Pool 检查（缓存命中率指标）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW STATUS LIKE 'Innodb_buffer_pool_reads';" >> $REPORT_FILE

echo "##3.20 InnoDB 死锁及长事务检查（通过 ENGINE INNODB STATUS）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW ENGINE INNODB STATUS\G" >> $REPORT_FILE

echo "##3.21 表缓存检查（opened_tables 与 table_open_cache）及查询缓存检查（query_cache）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW GLOBAL STATUS LIKE '%opened_tables%';" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE '%table_open_cache%';" >> $REPORT_FILE
echo "查询缓存检查（query_cache）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW VARIABLES LIKE '%query_cache%';" >> $REPORT_FILE

echo "##3.22 临时表检查（Created_tmp_tables, Created_tmp_disk_tables, Created_tmp_files）：" >> $REPORT_FILE
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW GLOBAL STATUS LIKE '%tmp%';" >> $REPORT_FILE

echo "##3.23 复制检查（Slave Status）：" >> $REPORT_FILE
SLAVE_STATUS=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST -P$MYSQL_PORT -e "SHOW SLAVE STATUS\G")
if echo "$SLAVE_STATUS" | grep -q "Slave_IO_Running"; then
    echo "$SLAVE_STATUS" >> $REPORT_FILE
else
    echo "该实例不是从库，跳过复制检查。" >> $REPORT_FILE
fi

echo "##3.24 备份检查自动化：" >> $REPORT_FILE
if [[ -d "$BACKUP_DIR" ]]; then
    RECENT_BACKUP=$(find "$BACKUP_DIR" -type f -name "mysql_backup_*.sql" -mtime -1 | head -n 1)
    if [[ -n "$RECENT_BACKUP" ]]; then
        echo "检测到最近的备份文件：$RECENT_BACKUP" >> $REPORT_FILE
        FILE_SIZE=$(stat -c %s "$RECENT_BACKUP")
        if [[ "$FILE_SIZE" -gt 0 ]]; then
            echo "备份文件大小：$FILE_SIZE bytes" >> $REPORT_FILE
        else
            echo "备份文件存在，但大小为 0，请检查备份任务！" >> $REPORT_FILE
        fi
    else
        echo "未检测到最近1天内的备份文件，请检查备份任务！" >> $REPORT_FILE
    fi
else
    echo "备份目录 $BACKUP_DIR 不存在，跳过备份检查。" >> $REPORT_FILE
fi

echo "" >> $REPORT_FILE

###############################################################################
#【4】注意：Python 脚本需手动执行生成 Word 报告
###############################################################################
echo "#【4】注意" >> $REPORT_FILE
echo "本脚本不自动调用 Python 生成报告，请在巡检完成后手动执行： python3 generate_report.py" >> $REPORT_FILE
