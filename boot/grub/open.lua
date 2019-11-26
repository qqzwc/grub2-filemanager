#!lua
-- Grub2-FileManager
-- Copyright (C) 2017,2018  A1ive.
--
-- Grub2-FileManager is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Grub2-FileManager is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Grub2-FileManager.  If not, see <http://www.gnu.org/licenses/>.

function div1024 (file_size, unit)
    part_int = file_size / 1024
    part_f1 = 10 * ( file_size % 1024 ) / 1024
    part_f2 =  10 * ( file_size % 1024 ) % 1024
    part_f2 = 10 * ( part_f2 % 1024 ) / 1024
    str = part_int .. "." .. part_f1 .. part_f2 .. unit
    return part_int, str
end

function get_size (file)
    if (file == nil) then
        return 1
    else
        file_data = grub.file_open (file)
        file_size = grub.file_getsize (file_data)
        str = file_size .. "B"
        for i,unit in ipairs ({"KiB", "MiB", "GiB", "TiB"}) do
            if (file_size < 1024) or (unit == "TiB") then
                break
            else
                file_size, str = div1024 (file_size, unit)
            end
        end
    end
    return (str)
end

function towinpath (file)
    win_path = string.match (file, "^%([%w,]+%)(.*)$")
    win_path = string.gsub (win_path, "/", "\\\\")
end

function tog4dpath (file, device, device_type)
    if (device_type == "1") then
        devnum = string.match (device, "^hd%d+,%a*(%d+)$")
        devnum = devnum - 1
        g4d_file = "(" .. string.match (device, "^(hd%d+,)%a*%d+$") .. devnum .. ")" .. string.match (file, "^%([%w,]+%)(.*)$")
    elseif (device_type == "2") then
        g4d_file = file
    else
        g4d_file = "(rd)+1"
    end
    --print ("grub4dos file path : " .. g4d_file)
end

function isoboot (iso_path, iso_label, iso_uuid, dev_uuid)
    if iso_label == nil then
        iso_label = ""
    end
    if iso_uuid == nil then
        iso_uuid = ""
    end
    if dev_uuid == nil then
        dev_uuid = ""
    end
    command = ""
    if string.match (iso_path, " ") ~= nil then
        command = "echo " .. grub.gettext ("File path contains spaces.This may cause problems!Press any key to continue.") .. "; getkey; "
    end
    if grub.file_exist ("(loop)/boot/grub/loopback.cfg") then
        icon = "gnu-linux"
        command = command .. "root=loop; export iso_path=" .. iso_path .. "; export rootuuid=" .. dev_uuid .. "; configfile /boot/grub/loopback.cfg"
        name = grub.gettext ("Boot ISO (Loopback)")
        grub.add_icon_menu (icon, command, name)
    end

    function enum_loop (loop_path)
        -- enum_loop path_without_(loop)
        -- return table
        i = 0
        f_table = {}
        function enum_loop_func (name)
            item = loop_path .. name
            if grub.file_exist ("(loop)" .. item) then
                i = i + 1
                f_table[i] = item
            elseif (name ~= "." and name ~= "..") then
                i = i + 1
                f_table[i] = item .. "/"
            end
        end
        grub.enum_file (enum_loop_func, "(loop)" .. loop_path)
        return f_table
    end

    function check_distro ()
        -- return icon, script, name, linux_extra
        -- default
        linux_extra = "iso-scan/filename=" .. iso_path
        -- check /
        list = enum_loop ("/")
        for i, loop_file in ipairs(list) do
            if string.match (loop_file, "^/[%d]+%.[%d]+/") then
                if grub.file_exist ("(loop)" .. loop_file .. "amd64/bsd.rd") or grub.file_exist ("(loop)" .. loop_file .. "i386/bsd.rd") then
                    return "openbsd", "openbsd", "OpenBSD", ""
                end
            end
            loop_file = string.lower (loop_file)
            if string.match (loop_file, "^/arch/") then
                linux_extra = "img_dev=/dev/disk/by-uuid/" .. dev_uuid .. " img_loop=" .. iso_path .. " archisolabel=" .. iso_label
                if grub.file_exist ("(loop)/boot/vmlinuz_x86_64") then
                    linux_extra = "iso_loop_dev=/dev/disk/by-uuid/" .. dev_uuid .. " iso_loop_path=" .. iso_path
                end
                return "archlinux", "archlinux", "Arch Linux", linux_extra
            elseif string.match (loop_file, "^/casper/") then
                linux_extra = "iso-scan/filename=" .. iso_path
                return "ubuntu", "ubuntu", "Ubuntu", linux_extra
            elseif string.match (loop_file, "^/liveos/") then
                linux_extra = "root=live:CDLABEL=" .. iso_label .. " iso-scan/filename=" .. iso_path
                return "fedora", "fedora", "Fedora", linux_extra
            elseif string.match (loop_file, "^/parabola/") then
                linux_extra = "img_dev=/dev/disk/by-uuid/" .. dev_uuid .. " img_loop=" .. iso_path .. " parabolaisolabel=" .. iso_label
                return "archlinux", "parabola", "Parabola", linux_extra
            elseif string.match (loop_file, "^/hyperbola/") then
                linux_extra = "img_dev=/dev/disk/by-uuid/" .. dev_uuid .. " img_loop=" .. iso_path .. " hyperisolabel=" .. iso_label
                return "archlinux", "hyper", "Hyperbola", linux_extra
            elseif string.match (loop_file, "^/blackarch/") then
                linux_extra = "img_dev=/dev/disk/by-uuid/" .. dev_uuid .. " img_loop=" .. iso_path .. " archisolabel=" .. iso_label
                return "archlinux", "blackarch", "BlackArch", linux_extra
            elseif string.match (loop_file, "^/kdeos/") then
                linux_extra = "img_dev=/dev/disk/by-uuid/" .. dev_uuid .. " img_loop=" .. iso_path .. " kdeisolabel=" .. iso_label
                return "kaos", "kaos", "KaOS", linux_extra
            elseif string.match (loop_file, "^/siduction/") then
                linux_extra = "fromiso=" .. iso_path
                return "siduction", "siduction", "siduction", linux_extra
            elseif string.match (loop_file, "^/sysresccd/") then
                linux_extra = "img_dev=/dev/disk/by-uuid/" .. dev_uuid .. " img_loop=" .. iso_path .. " archisolabel=" .. iso_label
                return "archlinux", "sysresccd", "System Rescue CD", linux_extra
            elseif string.match (loop_file, "^/sysrcd%.dat") then
                linux_extra = "isoloop=" .. iso_path
                return "gentoo", "sysrcd", "System Rescue CD", linux_extra
            elseif string.match (loop_file, "^/ipfire.*%.media") then
                linux_extra = " bootfromiso=" .. iso_path
                return "ipfire", "ipfire", "IPFire", linux_extra
            elseif string.match (loop_file, "^/dat[%d]+%.dat") then
                return "acronis", "acronis", "Acronis", ""
            elseif string.match (loop_file, "^/livecd%.sqfs") then
                linux_extra = "root=UUID=" .. dev_uuid .. " bootfromiso=" .. iso_path
                return "pclinuxos", "pclinuxos", "PCLinuxOS", linux_extra
            elseif string.match (loop_file, "^/livecd%.squashfs") then
                linux_extra = "isoboot=" .. iso_path .. " root=live:LABEL=" .. iso_label .. " iso-scan/filename=" .. iso_path
                return "gnu-linux", "calculate", "Calculate Linux", linux_extra
            elseif string.match (loop_file, "^/system%.sfs") then
                linux_extra = "iso-scan/filename=" .. iso_path
                return "android", "android", "Android-x86", linux_extra
            elseif string.match (loop_file, "^/netbsd") then
                return "netbsd", "netbsd", "NetBSD", ""
            elseif string.match (loop_file, "^/porteus/") then
                linux_extra = "from=" .. iso_path
                return "porteus", "porteus", "Porteus", linux_extra
            elseif string.match (loop_file, "^/slax/") then
                linux_extra = "from=" .. iso_path
                return "slax", "slax", "Slax", linux_extra
            elseif string.match (loop_file, "^/wifislax/") then
                linux_extra = "from=" .. iso_path
                return "wifislax", "wifislax", "Wifislax", linux_extra
            elseif string.match (loop_file, "^/wifislax64/") then
                linux_extra = "livemedia=/dev/disk/by-uuid/" .. dev_uuid .. ":" .. iso_path
                return "wifislax", "wifislax", "Wifislax64", linux_extra
            elseif string.match (loop_file, "^/wifiway/") then
                linux_extra = "from=" .. iso_path
                return "wifislax", "wifislax", "Wifiway", linux_extra
            elseif string.match (loop_file, "^/manjaro/") then
                linux_extra = "img_dev=/dev/disk/by-uuid/" .. dev_uuid .. " img_loop=" .. iso_path .. " misolabel=" .. iso_label
                return "manjaro", "manjaro", "Manjaro", linux_extra
            elseif string.match (loop_file, "^/chakra/") then
                linux_extra = "img_dev=/dev/disk/by-uuid/" .. dev_uuid .. " img_loop=" .. iso_path .. " chakraisolabel=" .. iso_label
                return "chakra", "chakra", "Chakra", linux_extra
            elseif string.match (loop_file, "^/pmagic/") then
                linux_extra = "iso_filename=" .. iso_path
                return "pmagic", "pmagic", "Parted Magic", linux_extra
            elseif string.match (loop_file, "^/antix/") then
                linux_extra = "fromiso=" .. iso_path .. " from=hd,usb"
                return "debian", "antix", "antiX", linux_extra
            elseif string.match (loop_file, "^/cdlinux/") then
                cdl_dir = string.match (iso_path, "^(.*)/.*$")
                cdl_img = string.match (iso_path, "^.*/(.*)$")
                linux_extra = "CDL_IMG=" .. cdl_img .. " CDL_DIR=" .. cdl_dir
                return "slackware", "cdlinux", "CDlinux", linux_extra
            elseif string.match (loop_file, "^/live/") then
                linux_extra = "findiso=" .. iso_path
                return "debian", "debian", "Debian", linux_extra
            elseif string.match (loop_file, "^/ploplinux/") then
                linux_extra = "iso_filename=" .. iso_path
                return "gnu-linux", "plop", "Plop Linux", linux_extra
            elseif string.match (loop_file, "^/liveslak/") then
                linux_extra = "livemedia=scandev:" .. iso_path
                return "slackware", "liveslack", "Slackware Live", linux_extra
            end
        end
        -- check /isolinux/
        list = enum_loop ("/isolinux/")
        for i, loop_file in ipairs(list) do
            loop_file = string.lower (loop_file)
            if string.match (loop_file, "^/isolinux/gentoo") then
                linux_extra = "isoboot=" .. iso_path
                return "gentoo", "gentoo", "Gentoo", linux_extra
            elseif string.match (loop_file, "^/isolinux/pentoo") then
                linux_extra = "isoboot=" .. iso_path
                return "gentoo", "pentoo", "Pentoo", linux_extra
            end
        end
        -- check /boot/
        list = enum_loop ("/boot/")
        for i, loop_file in ipairs(list) do
            loop_file = string.lower (loop_file)
            if string.match (loop_file, "^/boot/sabayon") then
                linux_extra = "isoboot=" .. iso_path
                return "sabayon", "sabayon", "Sabayon", linux_extra
            elseif string.match (loop_file, "^/boot/core%.gz") or string.match (loop_file, "^/boot/corepure64%.gz") then
                linux_extra = "iso=UUID=" .. dev_uuid .. iso_path
                return "gnu-linux", "tinycore", "TinyCore", linux_extra
            end
        end
        -- check /images/pxeboot/vmlinuz
        if grub.file_exist ("(loop)/images/pxeboot/vmlinuz") then
            linux_extra = "inst.stage2=hd:UUID=" .. iso_uuid .. " iso-scan/filename=" .. iso_path
            return "fedora", "fedora", "Fedora", linux_extra
        end
        -- check /kernels/huge.s/bzImage
        if grub.file_exist ("(loop)/kernels/huge.s/bzImage") then
            return "slackware", "slackware", "Slackware", ""
        end
        -- check /boot/isolinux/minirt.gz
        if grub.file_exist ("(loop)/boot/isolinux/minirt.gz") then
            linux_extra = "bootfrom=/dev/disk/by-uuid/" .. dev_uuid .. iso_path
            return "knoppix", "knoppix", "Knoppix", linux_extra
        end
        -- check /boot/kernel/
        if grub.file_exist ("(loop)/boot/kernel/kfreebsd.gz") or grub.file_exist ("(loop)/boot/kernel/kernel") then
            linux_extra = "(loop)" .. iso_path
            return "freebsd", "freebsd", "FreeBSD", linux_extra
        end
        -- check helenos
        if grub.file_exist ("(loop)/boot/kernel.bin") and grub.file_exist ("(loop)/boot/ns") then
            linux_extra = "(loop)" .. iso_path
            return "helenos", "helenos", "HelenOS", linux_extra
        end
        -- check /boot/x86_64/loader/linux /boot/i386/loader/linux
        if grub.file_exist ("(loop)/boot/x86_64/loader/linux") or grub.file_exist ("(loop)/boot/i386/loader/linux") or grub.file_exist ("(loop)/boot/ix86/loader/linux") then
            linux_extra = "isofrom_system=" .. iso_path .. " isofrom_device=/dev/disk/by-uuid/" ..dev_uuid
            return "opensuse", "suse64", "OpenSUSE", linux_extra
        end
        -- check /platform/i86pc/kernel/amd64/unix
        if grub.file_exist ("(loop)/platform/i86pc/kernel/amd64/unix") then
            return "solaris", "smartos", "SmartOS", ""
        end
        --check /sources/install.wim /x64/sources/install.esd
        if grub.file_exist ("(loop)/sources/install.wim") or grub.file_exist ("(loop)/sources/install.esd") or grub.file_exist ("(loop)/sources/install.swm") or grub.file_exist ("(loop)/x86/sources/install.esd") or grub.file_exist ("(loop)/x64/sources/install.esd") or grub.file_exist ("(loop)/x64/sources/install.wim") or grub.file_exist ("(loop)/x86/sources/install.wim") or grub.file_exist ("(loop)/x86/sources/install.swm") or grub.file_exist ("(loop)/x64/sources/install.swm") then
            linux_extra = string.gsub (iso_path, "/", "\\\\")
            return "nt6", "windows", "Windows", linux_extra
        end
        return "iso", "unknown", "Linux", ""
    end
    icon, distro, name, linux_extra = check_distro ()
    if distro ~= "unknown" then
        grub.exportenv ("linux_extra", linux_extra)
        command = command .. "export iso_path; export iso_uuid; export dev_uuid; " ..
         "configfile $prefix/distro/" .. distro .. ".sh"
        name = grub.gettext ("Boot ") .. name .. grub.gettext (" From ISO")
        grub.add_icon_menu (icon, command, name)
    end
    cfglist = {
        "(loop)/isolinux.cfg",
        "(loop)/isolinux/isolinux.cfg",
        "(loop)/boot/isolinux.cfg",
        "(loop)/boot/isolinux/isolinux.cfg",
        "(loop)/syslinux/syslinux.cfg"
    }
    for i,cfgpath in ipairs(cfglist) do
        if grub.file_exist (cfgpath) then
            icon = "gnu-linux"
            command = "export root=loop; theme=${prefix}/themes/slack/theme.txt; " ..
             "export linux_extra; syslinux_configfile -i " .. cfgpath
            name = grub.gettext ("Boot ISO (ISOLINUX)")
            grub.add_icon_menu (icon, command, name)
            break
        end
    end
    return 0
end

function open (file, file_type, device, device_type, arch, platform)
-- common
    icon = "go-previous"
    command = "export path=" .. path .. "; lua $prefix/main.lua"
    name = grub.gettext("Back")
    grub.add_icon_menu (icon, command, name)
-- 
    if file_type == "iso" then
        if device_type ~= "3" then
            -- mount
            grub.run ("loopback -d loop")
            grub.run ("loopback loop " .. file)
            icon = "iso"
            command = "export path= ; lua $prefix/main.lua"
            name = grub.gettext("Mount ISO")
            grub.add_icon_menu (icon, command, name)
            -- isoboot
            iso_path = string.match (grub.getenv ("file"), "^%([%w,]+%)(.*)$")
            grub.setenv ("iso_path", iso_path)
            grub.run ("probe --set=dev_uuid -u " .. device)
            dev_uuid = grub.getenv ("dev_uuid")
            grub.run ("probe -q --set=iso_label --label (loop)")
            iso_label = grub.getenv ("iso_label")
            grub.run ("probe --set=iso_uuid -u (loop)")
            iso_uuid = grub.getenv ("iso_uuid")
            isoboot (iso_path, iso_label, iso_uuid, dev_uuid)
        end
        if platform == "pc" then
            -- memdisk iso
            icon = "iso"
            command = "linux16 $prefix/memdisk iso raw; enable_progress_indicator=1; initrd16 " .. file
            name = grub.gettext("Boot ISO (memdisk)")
            grub.add_icon_menu (icon, command, name)
            -- grub4dos map iso
            icon = "iso"
            tog4dpath (file, device, device_type)
            command = "g4d_cmd=\"find --set-root /fm.loop;/MAP nomem cd " .. g4d_file .."\";" .. 
             "linux $prefix/grub.exe --config-file=$g4d_cmd; "
            if g4d_file == "(rd)+1" then
                command = command .. "enable_progress_indicator=1; initrd " .. file
            end
            name = grub.gettext("Boot ISO (GRUB4DOS)")
            grub.add_icon_menu (icon, command, name)
            -- easy2boot
            if string.match (device, "^hd[%d]+,msdos[1-3]") ~= nil then
                icon = "gnu-linux"
                devnum = string.match (device, "^(hd%d+),msdos[1-3]$")
                command = "echo " .. grub.gettext ("WARNING: Will erase ALL data on (hd0,4).") .. "; " .. 
                 "echo " .. grub.gettext ("Press [Y] to continue. Press [N] to quit.") .. "; " .. 
                 "getkey key; " .. 
                 "\nif [ x$key = x121 ]; then" .. 
                 "\n  partnew --type=0x00 --file=" .. file .. " " .. devnum .. " 4" ..
                 "\n  g4d_cmd=\"find --set-root /fm.loop;/MAP nomem cd " ..  g4d_file .. "\";" .. 
                 "\n  linux $prefix/grub.exe --config-file=$g4d_cmd; boot" .. 
                 "\nfi" .. 
                 "\necho " .. grub.gettext ("Canceled.") .. "; sleep 3"
                name = grub.gettext("Boot ISO (Easy2Boot)")
                grub.add_icon_menu (icon, command, name)
            end
        elseif platform == "efi" then
            -- map iso
            icon = "iso"
            command = "map " .. file
            name = grub.gettext("Boot ISO (map)")
            grub.add_icon_menu (icon, command, name)
            --map --mem
            icon = "iso"
            command = "map --mem " .. file
            name = grub.gettext("Boot ISO (map --mem)")
            grub.add_icon_menu (icon, command, name)
        end
    elseif file_type == "wim" then
        if platform == "efi" then
            icon = "wim"
            command = "set lang=en_US; loopback wimboot ${prefix}/wimboot.gz; wimboot @:bootmgfw.efi:(wimboot)/bootmgfw.efi @:bcd:(wimboot)/bcd @:boot.sdi:(wimboot)/boot.sdi @:boot.wim:" .. file
            name = grub.gettext("Boot NT6.x WIM (wimboot)")
            grub.add_icon_menu (icon, command, name)
            if device_type == "1" then
              -- NTBOOT
              icon = "wim"
              command = "set lang=en_US; loopback wimboot ${prefix}/wimboot.gz; ntboot --efi=(wimboot)/bootmgfw.efi --sdi=(wimboot)/boot.sdi " .. file
              name = grub.gettext("Boot NT6.x WIM (NTBOOT)")
              grub.add_icon_menu (icon, command, name)
            end
        elseif platform == "pc" then
            -- wimboot
            icon = "wim"
            command = "set lang=en_US; terminal_output console; enable_progress_indicator=1; loopback wimboot /wimboot; linux16 (wimboot)/wimboot; initrd16 newc:bootmgr:(wimboot)/bootmgr newc:bootmgr.exe:(wimboot)/bootmgr.exe newc:bcd:(wimboot)/bcd newc:boot.sdi:(wimboot)/boot.sdi newc:boot.wim:" .. file
            name = grub.gettext("Boot NT6.x WIM (wimboot)")
            grub.add_icon_menu (icon, command, name)
            -- BOOTMGR/NTLDR only supports (hdx,y)
            if device_type == "1" then
                -- NTBOOT NT6 WIM
                icon = "nt6"
                tog4dpath (file, device, device_type)
                command = "g4d_cmd=\"find --set-root /fm.loop;/NTBOOT NT6=" .. g4d_file .. "\";" .. 
                 "linux $prefix/grub.exe --config-file=$g4d_cmd; "
                name = grub.gettext("Boot NT6.x WIM (NTBOOT)")
                grub.add_icon_menu (icon, command, name)
                -- NTBOOT NT5 WIM (PE1)
                icon = "nt5"
                tog4dpath (file, device, device_type)
                command = "g4d_cmd=\"find --set-root /fm.loop;/NTBOOT pe1=" .. g4d_file .. "\";" .. 
                 "linux $prefix/grub.exe --config-file=$g4d_cmd; "
                name = grub.gettext("Boot NT5.x WIM (NTBOOT)")
                grub.add_icon_menu (icon, command, name)
            end
        end
    elseif file_type == "wpe" then
        if platform == "pc" then
            -- NTLDR only supports (hdx,y)
            if device_type == "1" then
                -- NTBOOT NT5 PE
                icon = "nt5"
                tog4dpath (file, device, device_type)
                command = "g4d_cmd=\"find --set-root /fm.loop;/NTBOOT pe1=" .. g4d_file .. "\";" .. 
                 "linux $prefix/grub.exe --config-file=$g4d_cmd; "
                name = grub.gettext("Boot NT5.x PE (NTBOOT)")
                grub.add_icon_menu (icon, command, name)
            end
        end
    elseif file_type == "vhd" then
        if device_type ~= "3" then
            -- mount
            icon = "img"
            command = "vhd -d vhd0; vhd -p vhd0 " .. file .. "; export path= ; lua $prefix/main.lua"
            name = grub.gettext("Mount Image")
            grub.add_icon_menu (icon, command, name)
        end
        if platform == "pc" then
            -- BOOTMGR only supports (hdx,y)
            if device_type == "1" then
                -- NTBOOT NT6 VHD
                icon = "nt6"
                tog4dpath (file, device, device_type)
                command = "g4d_cmd=\"find --set-root /fm.loop;/NTBOOT NT6=" .. g4d_file .. "\";" .. 
                 "linux $prefix/grub.exe --config-file=$g4d_cmd; "
                name = grub.gettext("Boot Windows NT6.x VHD/VHDX (NTBOOT)")
                grub.add_icon_menu (icon, command, name)
                -- VHD ramos -top
                icon = "nt6"
                command = "g4d_cmd=\"find --set-root --ignore-floppies --ignore-cd " .. g4d_file .. "; map --mem --top " .. g4d_file .. " (hd0); map (hd0) (hd1); map --hook; root (hd0,0); chainloader /bootmgr; boot\"; " .. 
                 "linux $prefix/grub.exe --config-file=$g4d_cmd; "
                name = grub.gettext("Boot RamOS VHD (GRUB4DOS map --mem --top)")
                grub.add_icon_menu (icon, command, name)
                -- VHD ramos
                icon = "nt6"
                command = "g4d_cmd=\"find --set-root --ignore-floppies --ignore-cd " .. g4d_file .. "; map --mem " .. g4d_file .. " (hd0); map (hd0) (hd1); map --hook; root (hd0,0); chainloader /bootmgr; boot\"; " .. 
                 "linux $prefix/grub.exe --config-file=$g4d_cmd; "
                name = grub.gettext("Boot RamOS VHD (GRUB4DOS map --mem)")
                grub.add_icon_menu (icon, command, name)
                -- VHD vboot
                icon = "img"
                vhd_path = string.match (grub.getenv ("file"), "^%([%w,]+%)(.*)$")
                grub.run ("probe --set=dev_uuid -u " .. device)
                dev_uuid = grub.getenv ("dev_uuid")
                command = "loopback vboot /vbootldr; set vbootloader=(vboot)/vboot;vbootinsmod (vboot)/vbootcore.mod; vboot harddisk=(UUID=" .. dev_uuid .. ")" .. vhd_path
                name = grub.gettext("Boot VHD (vboot)")
                grub.add_icon_menu (icon, command, name)
            end
        elseif platform == "efi" then
            if device_type == "1" then
              -- NTBOOT
              icon = "img"
              command = "set lang=en_US; terminal_output console; loopback wimboot ${prefix}/wimboot.gz; ntboot --gui --efi=(wimboot)/alt.efi " .. file
              name = grub.gettext("Boot Windows NT6.x VHD/VHDX (NTBOOT)")
              grub.add_icon_menu (icon, command, name)
            end
            -- map vhd
            icon = "img"
            command = "vhd -d vhd0; vhd -p vhd0 " .. file .. "; map --type=HD --disk vhd0"
            name = grub.gettext("Boot VHD (map)")
            grub.add_icon_menu (icon, command, name)
            --map --mem
            icon = "img"
            command = "vhd -d vhd0; vhd -p vhd0 " .. file .. "; map --mem --type=HD --disk vhd0"
            name = grub.gettext("Boot VHD (map --mem)")
            grub.add_icon_menu (icon, command, name)
        end
    elseif file_type == "fba" then
        if device_type ~= "3" then
            -- mount
            icon = "img"
            command = "loopback -d ud; loopback ud " .. file .. "; export path=(ud); lua $prefix/main.lua"
            name = grub.gettext("Mount Image")
            grub.add_icon_menu (icon, command, name)
        end
    elseif file_type == "disk" then
        if device_type ~= "3" then
            -- mount
            icon = "img"
            command = "loopback -d img; loopback img " .. file .. "; export path= ; lua $prefix/main.lua"
            name = grub.gettext("Mount Image")
            grub.add_icon_menu (icon, command, name)
        end
        if platform == "pc" then
            -- memdisk floppy
            icon = "img"
            command = "linux16 $prefix/memdisk floppy raw; enable_progress_indicator=1; initrd16 " .. file
            name = grub.gettext("Boot Floppy Image (memdisk)")
            grub.add_icon_menu (icon, command, name)
            -- grub4dos map fd
            icon = "img"
            tog4dpath (file, device, device_type)
            command = "g4d_cmd=\"find --set-root /fm.loop;/MAP nomem fd " .. g4d_file .. "\";" .. 
             "linux $prefix/grub.exe --config-file=$g4d_cmd; "
            if g4d_file == "(rd)+1" then
                command = command .. "enable_progress_indicator=1; initrd " .. file
            end
            name = grub.gettext("Boot Floppy Image (GRUB4DOS)")
            grub.add_icon_menu (icon, command, name)
            -- memdisk harddisk
            icon = "img"
            command = "linux16 $prefix/memdisk harddisk raw; enable_progress_indicator=1; initrd16 " .. file
            name = grub.gettext("Boot Hard Drive Image (memdisk)")
            grub.add_icon_menu (icon, command, name)
            -- grub4dos map hd
            icon = "img"
            tog4dpath (file, device, device_type)
            command = "g4d_cmd=\"find --set-root /fm.loop;/MAP nomem hd " .. g4d_file .. "\";" .. 
             "linux $prefix/grub.exe --config-file=$g4d_cmd; "
            if g4d_file == "(rd)+1" then
                command = command .. "enable_progress_indicator=1; initrd " .. file
            end
            name = grub.gettext("Boot Hard Drive Image (GRUB4DOS)")
            grub.add_icon_menu (icon, command, name)
        elseif platform == "efi" then
            -- map img
            icon = "img"
            command = "map " .. file
            name = grub.gettext("Boot IMG (map)")
            grub.add_icon_menu (icon, command, name)
            --map --mem img
            icon = "img"
            command = "map --mem " .. file
            name = grub.gettext("Boot IMG (map --mem)")
            grub.add_icon_menu (icon, command, name)
        end
    elseif file_type == "ipxe" then
        if platform == "pc" then
            -- ipxe
            icon = "net"
            command = "linux16 $prefix/ipxe.lkrn; initrd16 " .. file
            name = grub.gettext("Open As iPXE Script")
            grub.add_icon_menu (icon, command, name)
        end
    elseif file_type == "efi" then
        if platform == "efi" then
            -- efi
            icon = "uefi"
            command = "set lang=en_US; chainloader -b -t " .. file
            name = grub.gettext("Open As EFI Application")
            grub.add_icon_menu (icon, command, name)
            -- efi driver
            icon = "uefi"
            command = "efiload " ..file
            name = grub.gettext("Load UEFI driver")
            grub.add_icon_menu (icon, command, name)
        end
    elseif file_type == "nsh" then
        if platform == "efi" then
            -- nsh
            icon = "cfg"
            towinpath (file)
            command = "set lang=en_US; shell --nostartup \"" .. win_path .. "\""
            name = grub.gettext("Open As EFI Shell Script")
            grub.add_icon_menu (icon, command, name)
        end
    elseif file_type == "tar" then
        if device_type ~= "3" then
            -- mount
            icon = "7z"
            command = "loopback -d tar; loopback tar " .. file .. "; export path=(tar); lua $prefix/main.lua"
            name = grub.gettext("Open As Archiver")
            grub.add_icon_menu (icon, command, name)
        end
    elseif file_type == "cfg" then
        -- GRUB 2 menu
        icon = "cfg"
        command = "root=" .. device .. "; configfile " .. file
        name = grub.gettext("Open As Grub2 Menu")
        grub.add_icon_menu (icon, command, name)
        -- Syslinux menu
        icon = "cfg"
        command = "root=" .. device .. "; syslinux_configfile -s " .. file
        name = grub.gettext("Open As Syslinux Menu")
        grub.add_icon_menu (icon, command, name)
        -- pxelinux menu
        icon = "cfg"
        command = "root=" .. device .. "; syslinux_configfile -p " .. file
        name = grub.gettext("Open As pxelinux Menu")
        grub.add_icon_menu (icon, command, name)
    elseif file_type == "lst" then
        if platform == "pc" then
            if device_type ~= "3" then
                -- GRUB4DOS menu
                icon = "cfg"
                tog4dpath (file, device, device_type)
                command = "g4d_cmd=\"find --set-root /fm.loop;configfile " .. g4d_file .. "\";" .. 
                 "linux $prefix/grub.exe --config-file=$g4d_cmd; "
                name = grub.gettext("Open As GRUB4DOS Menu")
                grub.add_icon_menu (icon, command, name)
            end
        end
        -- GRUB-Legacy menu
        icon = "cfg"
        command = "root=" .. device .. "; legacy_configfile " .. file
        name = grub.gettext("Open As GRUB-Legacy Menu")
        grub.add_icon_menu (icon, command, name)
    elseif file_type == "pf2" then
        -- PF2 font
        icon = "pf2"
        command = "loadfont " .. file
        name = grub.gettext("Open As Font")
        grub.add_icon_menu (icon, command, name)
    elseif file_type == "mod" then
        -- insmod
        icon = "mod"
        command = "insmod " .. file
        name = grub.gettext("Insert Grub2 Module")
        grub.add_icon_menu (icon, command, name)
    elseif file_type == "image" then
        -- png/jpg/tga
        icon = "png"
        command = "background_image " .. file .. "; echo -n " .. grub.gettext ("Press [ESC] to continue...") .. "; " .. 
         "getkey; background_image ${prefix}/themes/slack/black.png"
        name = grub.gettext("Open As Image")
        grub.add_icon_menu (icon, command, name)
    elseif file_type == "lua" then
        -- lua
        icon = "lua"
        command = "root=" .. device .. "; lua " .. file .. "; getkey"
        name = grub.gettext("Open As Lua Script")
        grub.add_icon_menu (icon, command, name)
--  elseif file_type == "py" then
        -- python
--      icon = "py"
--      old_root = grub.getenv ("root")
--      command = "search -s -f /boot/python/lib.zip; pyrun " .. file .. "; getkey; export root=" .. old_root
--      name = grub.gettext("Open As Python Script")
--      grub.add_icon_menu (icon, command, name)
    elseif grub.run ("file --is-x86-multiboot " .. file) == 0 then
        -- multiboot
        icon = "exe"
        command = "multiboot " .. file
        name = grub.gettext("Boot Multiboot Kernel")
        grub.add_icon_menu (icon, command, name)
    elseif grub.run ("file --is-x86-multiboot2 " .. file) == 0 then
        -- multiboot2
        icon = "exe"
        command = "multiboot2 " .. file
        name = grub.gettext("Boot Multiboot2 Kernel")
        grub.add_icon_menu (icon, command, name)
    elseif grub.run ("file --is-x86-linux " .. file) == 0 then
        -- linux kernel
        icon = "exe"
        command = "linux " .. file
        name = grub.gettext("Boot Linux Kernel")
        grub.add_icon_menu (icon, command, name)
    end
-- common
    if platform == "pc" then
        if grub.run ("file --is-x86-bios-bootsector " .. file) == 0 then
            -- chainloader
            icon = "bin"
            command = "chainloader --force " .. file
            name = grub.gettext("Chainload BIOS Boot Sector")
            grub.add_icon_menu (icon, command, name)
        end
        if string.match (string.lower (file), "/[%w]+ldr$") ~= nil then
            -- ntldr
            icon = "wim"
            command = "ntldr " .. file
            name = grub.gettext("Chainload NTLDR")
            grub.add_icon_menu (icon, command, name)
        elseif string.match (string.lower (file), "/bootmgr$") ~= nil then
            -- bootmgr
            icon = "wim"
            command = "ntldr " .. file
            name = grub.gettext("Chainload BOOTMGR")
            grub.add_icon_menu (icon, command, name)
        end
        if device_type ~= 3 then
            icon = "mod"
            tog4dpath (file, device, device_type)
            command = "g4d_cmd=\"find --set-root /fm.loop;command " .. g4d_file .. "\";" .. 
             "linux $prefix/grub.exe --config-file=$g4d_cmd; "
            name = grub.gettext("Open As GRUB4DOS MOD")
            grub.add_icon_menu (icon, command, name)
        end
    end
    
    -- text viewer
    icon = "txt"
    command = "unset line_num; export file=" .. file .. "; lua $prefix/text.lua"
    name = grub.gettext ("Text Viewer")
    grub.add_icon_menu (icon, command, name)
    -- hex viewer
    icon = "bin"
    command = "unset offset; export file=" .. file .. "; lua $prefix/hex.lua"
    name = grub.gettext ("Hex Viewer")
    grub.add_icon_menu (icon, command, name)
    -- file info
    file_size = get_size (file)
    icon = "info"
    command = "echo File Path : " .. file .. "; echo File Size : " .. file_size .. "; " .. 
     "enable_progress_indicator=1; echo CRC32 : ; crc32 " .. file .. "; enable_progress_indicator=0; " .. 
     "echo hexdump; hexdump " .. file .. "; echo -n Press [ESC] to continue...; getkey"
    name = grub.gettext ("File Info")
    grub.add_icon_menu (icon, command, name)
end

encoding = grub.getenv ("encoding")
if (encoding == nil) then
    encoding = "utf8"
end
path = string.gsub(grub.getenv ("path"), " ", "\\ ")
file = string.gsub(grub.getenv ("file"), " ", "\\ ")
file_type = grub.getenv ("file_type")
arch = grub.getenv ("grub_cpu")
platform = grub.getenv ("grub_platform")
device = string.match (file, "^%(([%w,]+)%)/.*$")
if string.match (device, "^hd[%d]+,[%w]+") ~= nil then
-- (hdx,y)
    device_type = "1"
elseif string.match (device, "^[hcf]d[%d]*") ~= nil then
-- (hdx) (cdx) (fdx) (cd)
    device_type = "2"
else
-- (loop) (memdisk) (tar) (proc) etc.
    device_type = "3"
end
grub.exportenv ("theme", "slack/f2.txt")
grub.clear_menu ()
open (file, file_type, device, device_type, arch, platform)
-- hidden menu
hotkey = "f1"
command = "lua $prefix/help.lua"
grub.add_hidden_menu (hotkey, command, "Help")
hotkey = "f3"
command = "lua $prefix/osdetect.lua"
grub.add_hidden_menu (hotkey, command, "Boot")
hotkey = "f4"
command = "lua $prefix/settings.lua"
grub.add_hidden_menu (hotkey, command, "Settings")
hotkey = "f5"
command = "lua $prefix/power.lua"
grub.add_hidden_menu (hotkey, command, "Reboot")
