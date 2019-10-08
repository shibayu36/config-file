> JVMのプロセスの特定
sudo jps -v

> 特定プロセスのJVMのメモリ使用状況を確認
sudo jstat -gc -t -h5 <PID> 1000
