#!/bin/bash


#Define a tempory working file name
TEMPFILE="_working.tmp"
#Define a default outputfile
DEFAULTOUTPUT="output_default.csv"
#Define log file name
LOGFILE="process_trades.log"

#Define a constant for sorting the output file by symbol. If no sorting is needed, then change it to
#SORT=false
SORT="true"
#DEFINE log level constants
LOG_ERROR=9
LOG_DEBUG=0
LOG_LEVEL=$LOG_DEBUG

#Define email notification subject line
SUBJECT="$0 process status report"
#Define email Recipients
RECIPIENTS=binlu99@gmail.com

#Function log messages into log file
#Function name: addLog
#Function required parameters: log_level message
#Example: addLog log_level message
function addLog()
{
	local log_level=$1
	local message=$2
	if [ $log_level -eq $LOG_LEVEL ]; then
		echo "[$(date)} $message" >> $LOGFILE
	fi
}

#Function processing each line of the input file
#Function name: process
#Function required parameters: timestamp symbol quantity price
#Example process timestamp symbol quantity price

function process( )
{
	local timestamp=$1
	local symbol=$2
	local quantity=$3
	local price=$4
	
	local timegap=0
	local volume=0
	local grandtotal=0
	local maxprice=0

#Check the symbl exist in the tempry working file
	rowcount=$(grep ^${symbol} ${TEMPFILE} |wc -l)
	
	case "$rowcount" in
	0) 
		addLog $LOG_DEBUG "Symbol $symbol not found in the working file and will be processed as initial one"
		timegap=0
		volume=$quantity
		grandtotal=$(( ${quantity}*${price} ))
		maxprice=$price
		;;	
	1) 
		addLog $LOG_DEBUG "Symbol $symbol not found in the working file and will be processed"
		current=$(grep ^${symbol}, ${TEMPFILE} |head -1)
		cur_time_stamp=$(echo $current | cut -d, -f2)
		cur_time_gap=$(echo $current | cut -d, -f3)	
		new_gap=$(( $timestamp - $cur_time_stamp ))
		if [ $new_gap -gt $cur_time_gap ]; then
			timegap=$new_gap
		else
			timegap=$cur_time_gap
		fi
		cur_volume=$(echo $current | cut -d, -f4)
		volume=$(( $cur_volume + $quantity ))
		cur_grand_total=$(echo $current | cut -d, -f5)
		grandtotal=$(( $cur_grand_total + $quantity*$price ))
		cur_price=$(echo $current | cut -d, -f6)
		if [ $price -gt $cur_price ]; then
			maxprice=$price
		else
			maxprice=$cur_price
		fi
		;;
	*) 
		echo "Error: something wrong in the working file"
		return
		;;
	esac
	
	aresult=$(aggregate $symbol $timestamp $timegap $volume $grandtotal $maxprice)
	echo "$aresult"
}

#Function to aggregate by symbol
#Function name: aggregate
#Required paramenters: symbol last_timestamp time_gap volume grand_total max_price
#Example:
# aggregate symbol last_timestamp time_gap volume grand_total max_price
function aggregate()
{
	if [ $# -ne 6 ]; then
		echo "Invalidat funcftion call for aggregate"
		return
	fi
	
	local symbol=$1
	local last_timestamp=$2
	local time_gap=$3
	local volume=$4
	local grand_total=$5
	local max_price=$6

	addLog $LOG_DEBUG "Aggregating symbol $symbol"
	newline="$symbol,$last_timestamp,$time_gap,$volume,$grand_total,${max_price}"
	existingline=$(grep ^${symbol}, ${TEMPFILE} |head -1)
	
	if [ x$existingline = "x" ]; then
		addLog $LOG_DEBUG  "Symbol $symbol not found in the working file and going to be added"
		echo $newline >> $TEMPFILE
	else
		addLog $LOG_DEBUG "Symbol $symbol is found in the working file and going to be updated"
		sed -i "s/${existingline}/${newline}/g" $TEMPFILE
	fi

	echo "SUCCESS"
	

}

#Function to generate output file
#Function name: createOutputFile
#Required paramenters: source_file output_file [sort]
#sort is optional. if presents, then output will be sort by symoble
#Example: createOutputFile source_file output_file sort
function createOutputFile()
{
	local infile
	local outfile
	local sort

	if [ $# -eq 2 ]; then
        	infile=$1
		outfile=$2
	elif [ $# -eq 3 ]; then
		infile=$1
		outfile=$2
		sort=$3
	else        
		echo "Error: Invalidat funcftion call for $0"
               	return
       	fi

	awk -F "," '{print $1","$3","$4","int($5/$4)","$6}' $infile > _${outfile}.tmp

	if [ x$sort = "xtrue" ]; then
		cat _${outfile}.tmp |sort > ${outfile}
	else
		mv _${outfile}.tmp ${outfile}
	fi

	echo "SUCCESS"

}

#Function to send out email for the process status and output file
#Function name: sendEmail
#function required parameters: starttime endtime subject status [attached_file]
#Attached file is optional
#Example sendEmail starttime endtime subject status [attached_file]
function sendEmail()
{
	if [ "x$SEND_EMAIL" != "xtrue" ]; then
		return
	fi

	local starttime
	local endtime
	local subject
	local status
	local attached_file
	if [ $# -eq 4 ]; then
		starttime=$1
		endtime=$2
		subject=$3
		status=$4
        elif [ $# -eq 5 ]; then
		starttime=$1
                endtime=$2
                subject=$3
                status=$4
		attached_file=$5
        else
                echo "Error: Invalidat funcftion call for $0"
                return
        fi

	emailbody="
Process started at $starttime\n
Process ended at $endtime\n
Process Status: $status\n
"
	if [ x$attached_file = "x" ]; then
		echo -e $emailbody|mailx -s "$subject" $RECIPIENTS 
	else
		echo -e $emailbody|mailx -s "$subject" -a $attached_file $RECIPIENTS
	fi

}


#Function to clean up tempory files
#Function name:icleanup
#function required parameters: None
#Example : cleanup
function cleanup()
{
	addLog $LOG_DEBUG "cleaning up the tempory files"
	rm _*.tmp
}

#Main program starts from here
if [ $# -ne 2 ] && [ $# -ne 0 ];
then
	cat <<ENDUSAGE
Usage:
$0 < input_file > output_file
or
$0 input_file out_file

Set environment variable SEND_EMAIL=true if need to send out email.
export SEND_EMAIL=true
ENDUSAGE
	exit 9
fi

#Now capture start time
starttime=$(date +"%Y-%m-%d-%T")
INFILE=$1
OUTFILE=$2

#Clean the log file
if [ -f $LOGFILE ];
then
	rm $LOGFILE
fi

if [ "x$INFILE" != "x" ] && [ ! -f $INFILE ];
then
	addLog $LOG_DEBUG "Input file $INFILE does not exist"
	endtime=$(date +"%Y-%m-%d-%T")
	sendEmail $starttime $endtime "${SUBJECT}" "Failed:Input file $INFILE does not exist" $LOGFILE
	exit 9
fi

if [ "x$OUTFILE" = "x" ];
then 
	OUTFILE=$DEFAULTOUTPUT
fi

if [ -f $OUTFILE ];
then
	addLog $LOG_DEBUG "Output file $OUTFILE exist already and it will be cleared now"
	rm $OUTFILE
fi

#Remove the tempory working file if exist already
if [ -f $TEMPFILE ];
then
	rm $TEMPFILE
fi

#Creating a temporty empty working file
touch $TEMPFILE

addLog $LOG_DEBUG "Now start processing "

while read line 
do
	addLog $LOG_DEBUG "Processing $line"
	TIMESTAMP=$(echo $line | cut -d, -f1)
	SYMBOL=$(echo $line | cut -d, -f2)
	QUANTITY=$(echo $line | cut -d, -f3)
	PRICE=$(echo $line | cut -d, -f4)
	result=$(process $TIMESTAMP $SYMBOL $QUANTITY $PRICE)
	if [ "$result" != "SUCCESS" ]; then
		endtime=$(date +"%Y-%m-%d-%T")
		addLog $LOG_ERROR $result
		sendEmail $starttime $endtime "${SUBJECT}" "Failed: $result" $LOGFILE
		cleanup
		exit 9
	else
		addLog $LOG_DEBUG $result
	fi

done < ${INFILE:-"/dev/stdin"}


#Now generate output file
#By default the output will be sorted by symbol
result=$(createOutputFile $TEMPFILE $OUTFILE $SORT)

#Now capture process end time
endtime=$(date +"%Y-%m-%d-%T")
if [ "$result" != "SUCCESS" ]; then
	addLog $LOG_ERROR $result
	sendEmail $starttime $endtime "${SUBJECT}" "Failed: $result" $LOGFILE
	cleanup
	exit 9
fi

sendEmail $starttime $endtime "${SUBJECT}" "SUCCESS" $OUTFILE

cat $OUTFILE

#Clean up the tempory files
cleanup

addLog $LOG_DEBUG "Process finished successfully"

