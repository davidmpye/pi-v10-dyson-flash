#! /bin/bash -x
{

function unlock_mcu() {
	echo "Bringing up SAMD20 in halt state"

	raspi-gpio set 18 op dl
	raspi-gpio set 25 op dl
	sleep 1
	raspi-gpio set 18 op dh

	echo "Unlocking processor"

	./openocd -f $CFG_FILE \
             -c "transport select swd" \
             -c "adapter speed 1000" \
             -c "reset_config srst_only" \
             -f at91samdXX.cfg  \
             -c "init; at91samd.cpu mwb 0x41002100 0x10; reset; halt; exit"

	return $?
}

function flash_mcu() {
        ./openocd -f $CFG_FILE \
                -c "transport select swd" \
                -c "adapter speed 1000" \
                -f at91samdXX.cfg \
                -c "program $FILENAME verify reset exit"
}

echo "Preparing to reflash Dyson V10 battery pack"

echo "Figuring out which kind of Pi we are running on"

IOADDR="`xxd -c 4 -g 4 /proc/device-tree/soc/ranges | sed '2!d;q' | cut -d ' ' -f 2`"
echo "Got ${IOADDR}"

FILENAME="/boot/V10_BMS.elf"

CFG_FILE=

if [[ "$IOADDR" == "20000000" ]]; then
	echo "Detected RPi V1/Zero - using IO address 20000000"
	CFG_FILE="rpi1.cfg"
elif [[ "$IOADDR" == "00000000" ]]; then
	echo "Detected RPI4 - using IO address  0xFE000000"
	CFG_FILE="rpi4.cfg"
elif [[ "$IODDR" == "3f000000" ]]; then
	echo "Detected RPi V2+ - using IO address 0x3F000000"
	CFG_FILE="rpi2.cfg"
fi

cp ${FILENAME} .
if [ $? -eq 0 ]; then
	echo "Image copied successfully"
else
	echo "Error: Unable to locate dyson.elf image file on boot partition - aborting flash process"
	exit 1
fi

RESULT=
for i in `seq 10`; do
	echo "Attempting to unlock/erase MCU - attempt ${i}"
	unlock_mcu
	RESULT=$?
	if [ ${RESULT} -eq 0 ]; then
		echo "Pack unlocked/erased successfully"
		break
	fi
	echo "Unlock failed, pausing 2 seconds, then retrying"
	sleep 2
done

if [ ${RESULT} -ne 0 ]; then
	echo "Unable to unlock pack - aborting"
	exit 1
fi

RESULT=
for i in `seq 10`; do
	echo "Programming MCU - attempt ${i}"
	flash_mcu
	RESULT=$?
	if [ ${RESULT} -eq 0 ]; then
		echo "Programming successful"
		break
	fi
	echo "Programming failed, pausing 2 seconds, then retrying"
	sleep 2
done

if [ ${RESULT} -ne 0 ]; then
	echo "Unable to program pack - aborting"
	exit 1
fi


} 2>&1 | tee -a /boot/flash_log.txt

sync

