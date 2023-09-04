#! /bin/bash -x
{

FILENAME="/boot/V10_BMS.elf"
export FILENAME

SWCLK=25
SWDIO=24
SRST=18
export SWCLK SWDIO SRST

function unlock_mcu() {
	echo "Bringing up SAMD20 in halt state"

	echo "Exporting SWCLK and SRST pins."
	echo $SWCLK > /sys/class/gpio/export
	echo $SRST > /sys/class/gpio/export
	echo "out" > /sys/class/gpio/gpio$SWCLK/direction
	echo "out" > /sys/class/gpio/gpio$SRST/direction

	echo "Setting SWCLK low and pulsing SRST."
	echo "0" > /sys/class/gpio/gpio$SWCLK/value
	echo "0" > /sys/class/gpio/gpio$SRST/value
	sleep 1
	echo "1" > /sys/class/gpio/gpio$SRST/value

	echo "Unexporting SWCLK and SRST pins."
	echo $SWCLK > /sys/class/gpio/unexport
	echo $SRST > /sys/class/gpio/unexport

	echo "Unlocking processor"

./openocd --debug -c "adapter driver sysfsgpio; \\
sysfsgpio_swclk_num $SWCLK; \\
sysfsgpio_swdio_num $SWDIO; \\
sysfsgpio_srst_num $SRST; \\
transport select swd; \\
source [find at91samdXX.cfg]; \\
reset_config srst_only; \\
init; at91samd.cpu mwb 0x41002100 0x10; sleep 500; reset; halt; exit"\

	return $?
}

function flash_mcu() {
echo "Starting flash process"
./openocd --debug -c "adapter driver sysfsgpio; \\
sysfsgpio_swclk_num $SWCLK; \\
sysfsgpio_swdio_num $SWDIO; \\
sysfsgpio_srst_num $SRST; \\
transport select swd; \\
source [find at91samdXX.cfg]; \\
reset_config srst_only; \\
program $FILENAME verify; \\
reset; \\
shutdown"

return $?
}

echo "Preparing to reflash Dyson V10 battery pack"

RESULT=
for i in `seq 5`; do
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
for i in `seq 5`; do
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
