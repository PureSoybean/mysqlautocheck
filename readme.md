# 使用说明和限制
✅ 支持 MySQL 和系统巡检

✅ 自动导出为 Word

✅ 适用于 CentOS 7

✅ 可以定时任务定期运行

# 参数说明
- MySQL 配置（请根据实际情况修改）
MYSQL_USER="root"
MYSQL_PASSWORD="123"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
- 默认数据库（用于部分命令）
MYSQL_DATABASE="mysql"
- 数据目录（用于超大库检查）
MYSQL_DATA_DIR="/oradata"
- 备份文件存放目录（请根据实际情况修改）
BACKUP_DIR="/backup/mysql"


# 巡检内容
该脚本巡检内容主要包括三部分：
 - 操作系统基础信息（主机名、发型版本、硬件信息、网络等）

 - 性能检查（CPU、内存、磁盘 I/O、开放端口、进程、系统日志等）

 - 数据库巡检（进程、版本、超大库表检查、慢查询、错误日志、重要参数、QPS、连接数、线程状态、InnoDB 状态、缓存、临时表、复制状态及备份提示等）

# 使用说明
1. 赋予执行权限
```bash
chmod +x mysql_system_check.sh
```

2. 执行巡检脚本
脚本执行后会生成 mysql_system_report.log 文件。
```bash
./mysql_system_check.sh
```

3. 手动执行 Python 脚本生成 Word 报告
生成 mysql_system_report.docx 文件。
```bash
python3 generate_report.py
```

4. 定时任务
每天 08:00 自动执行巡检（Word 报告由手动执行 Python 脚本生成）。
```bash
0 8 * * * /path/to/mysql_system_check.sh
```
