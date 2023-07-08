#! /usr/bin/expect
#

#exp_internal 1

set username [lindex $argv 0]

if { $argc != 1 } {
    puts "You need to specify two arguments to this script:\n"
    puts "<username>"
    exit 1
}


spawn /bin/sh -c "cd /root; ./openvpn-install.sh"

while (1) {
    expect {
        "Option: " {
            # удалить OpenVPN (потом переустановим снова)
            send "1\n"
        }
        "Name: " { send "$username\n" }
        eof { break }
    }
}

exit 0
