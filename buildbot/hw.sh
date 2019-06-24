#!/bin/sh
# Output single-line hardware description
#   model ; cpu ; RAM ; disk ; GPU

model() {
   if test -d /Library
   then
      sysctl -n hw.model
   else
      md=$(sudo dmidecode -s system-manufacturer)
      if test "$mn" = ""
      then
        pn=$(sudo dmidecode -s baseboard-manufacturer)
      fi
      echo "$pn" | sed 's/ Inc\.//;s/ Corporation//' | tr '\012' ' '
      pn=$(sudo dmidecode -s system-product-name | sed 's/Precision Tower //;s/Precision WorkStation //;s/   *$//')
      if test "$pn" = ""
      then
        pn=$(sudo dmidecode -s baseboard-product-name)
      fi
      echo "$pn"
   fi
}

cpu() {
   if test -d /Library
   then
      sysctl -n machdep.cpu.brand_string | sed 's/.*) //;s/ CPU.*//'
   else
      cat /proc/cpuinfo | grep 'model name' | sed 's/.*: //;s/(R)//;s/(TM)//;s/ CPU//;s/Core //;s/   */ /;s/  / /' | sort -u
   fi
}

ram() {
   if test -d /Library
   then
      sysctl -n hw.memsize | awk '{printf "%sG\n", $1 / (1024*1024*1024)}'
   else
      free -h | awk '/Mem:/ {print $2}'
   fi
}

disk() {
   if test -d /Library
   then
      diskutil info disk0 | grep 'Media Name' | sed 's/.*://;s/^ *//'
   else
      volume=$(df / | grep dev | sed 's, .*,,')
      case $volume in
      *mapper*)
         volume=$(sudo lvs -o +devices $volume | grep dev | sed 's/.* //;s/([0-9]*)$//')
         ;;
      esac
      device=$(echo $volume | sed 's,/dev/,,;s/p[0-9]*$//;s/sda[0-9]/sda/')
      cat /sys/block/$device/device/model
   fi
}

gpu() {
   if test -d /Library
   then
      system_profiler SPDisplaysDataType | grep 'Chipset Model' | sed 's/.*: //'
   else
      lspci | grep VGA |
	 sed 's/.*: //;s/Corporation //;s/ (rev.*)//' |
	 sed 's/NVIDIA GP107 .GeForce GTX 1050 Ti./Nvidia gtx1050ti/;s/NVIDIA GP104 .GeForce GTX 1080./Nvidia gtx1080/' |
	 sed 's,Advanced Micro Devices. Inc. .AMD/ATI. Cape Verde PRO .FirePro W600.,ATI w600,' |
	 sed 's,Advanced Micro Devices. Inc. .AMD/ATI. Vega .Radeon RX Vega M.,ATI Radeon RX Vega M,' |
	 cat
   fi
}

ether() {
   if test -d /Library
   then
      eth=$(route -n get default | awk '/interface:/ {print $2}')
      ifconfig $eth | awk '/inet / {print $2}'
      ifconfig $eth | awk '/ether/ {print $2}'
   else
      eth=$(route -n | awk '$1 == "0.0.0.0" && $2 != "0.0.0.0" {print $8}')
      ip addr show dev $eth | awk '/inet / {print $2}' | sed 's,/.*,,'
      ip addr show dev $eth | grep ether | awk '{print $2}'
   fi
}

serial() {
   if test -d /Library
   then
      ioreg -l | awk '/IOPlatformSerialNumber/ {print $4}' | tr -d '"'
   else
      sudo dmidecode -s system-serial-number
   fi
}

(
   model
   cpu
   ram
   disk
   gpu
   ether
   serial
) | sed 's/  *$//' | tr '\012' ';' | sed 's/;$/|/;s/;/; /g' | tr '|' '\012' | grep .
