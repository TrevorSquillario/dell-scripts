#!/bin/bash
while getopts o: flag
do
    case "${flag}" in
        o) OUTPUT_DIR=${OPTARG};;
    esac
done

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_FILE="`date +"%Y%m%d"`"
else
    OUTPUT_FILE="${OUTPUT_DIR}/`date +"%Y%m%d"`"
fi

# Get total number of cores
NPROCS="$(nproc)"
echo "Total Cores: ${NPROCS}" >> "${OUTPUT_FILE}_stress.log" 2>&1

# Save 2 cores, one for fio and one for the OS
STRESSPROCS="$(($NPROCS - 2 ))"
echo "Cores to use for stress: ${STRESSPROCS}" >> "${OUTPUT_FILE}_stress.log" 2>&1

# Use half of those cores for running stress on CPU and half for Memory
STRESSPROCSHALF="$(($STRESSPROCS / 2 ))" >> "${OUTPUT_FILE}_stress.log" 2>&1

# Get total memory
MEMTOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMTOTAL_MB="$(($MEMTOTAL / 1024))"
echo "Total Memory: ${MEMTOTAL_MB} MB" >> "${OUTPUT_FILE}_stress.log" 2>&1

# Calculate memory per process
VMPERWORKER="$(($MEMTOTAL_MB / $STRESSPROCSHALF))"
echo "Memory Per Process: ${VMPERWORKER} MB" >> "${OUTPUT_FILE}_stress.log" 2>&1

# Start fio and run until 10GB is written
#fio --name=write_iops --size=10G --directory=/data \
#    --ramp_time=2s --ioengine=libaio --direct=1 \
#    --verify=0 --bs=4K --iodepth=64 --rw=randwrite --group_reporting=1 

# Get physical disks (WARNING: THIS IS DESTRUCTIVE)
DISKS=$(lsblk -nd --output NAME)
DISKS_EXCLUDE=("sda" "sr0")
for d in $DISKS; do
    if [[ ${DISKS_EXCLUDE[*]} =~ $d ]] 
    then
        echo "Skipping /dev/${d}"
    else
        echo "Running badblocks on /dev/${d}"
        # Matching -b <blocksize> with your filesystem block size will increse perfornace
        badblocks -wsv -b 4096 -c 32768 /dev/$d >> "${OUTPUT_FILE}_badblocks_${d}.log" 2>&1 &
    fi
done

# Start stress in the background
stress -c $STRESSPROCSHALF --vm $STRESSPROCSHALF --vm-bytes "${VMPERWORKER}M" --timeout 86400 --verbose  >> "${OUTPUT_FILE}_stress.log" 2>&1 &
