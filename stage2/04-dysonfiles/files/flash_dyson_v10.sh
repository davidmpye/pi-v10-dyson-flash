#! /bin/bash
{
echo "Preparing to reflash Dyson V10 battery pack"

echo "Figuring out which kind of Pi we are running on"

IOADDR="`xxd -c 4 -g 4 /proc/device-tree/soc/ranges | sed '2!d;q' | cut -d ' ' -f 2`"

FILENAME="/boot/V10_BMS.elf"

CFG_FILE=

if [[ "$IOADDR" == "20000000" ]]; then
	echo "Detected RPi V1/Zero - using IO address 20000000"
	CFG_FILE="rpi1.cfg"
else
	echo "Detected RPi V2+ - using IO address 3f000000"
	CFG_FILE="rpi2.cfg"
fi

if [ $? -eq 0 ]; then
	echo "Image copied successfully"
else
	echo "Error: Unable to locate dyson.elf image file on boot partition - aborting flash process"
	exit 1
fi

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
             -c "init; at91samd.cpu mwb 0x41002100 0x10; halt; exit"

echo "Reflashing"
./openocd -f $CFG_FILE \
	-c "transport select swd" \
	-c "adapter speed 1000" \
	-f at91samdXX.cfg \
	-c "program $FILENAME verify reset exit"

[ $? -eq 0 ] && echo "Flashing completed successfully"

} 2>&1 | tee -a /boot/flash_log.txt


while true; do
	sleep 1000
done
