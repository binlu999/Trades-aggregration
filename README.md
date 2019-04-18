# Trades-aggregration

The source code is a bash script file. 
File name is process_trades.sh. 
It is running on Linux
bash shell. There is no need to build.
It can be run as following two options
## Use shell Input/Output redirections
```
./process_trades.sh < input_file > output_file
```

## Without shell redirection
```
./process_trades.sh input_file output_file
```
If an environment variable SEND_EMAIL exists and its value is true, then the code will send out
an email when it finishes its job. The email will have job status and output file attached if it
finished without error. Otherwise, it will have a log file attached.
To set environment variable SEND_EMAIL=true , use the following command before execute
this codes:
```
export SEND_EMAIL=true
```
