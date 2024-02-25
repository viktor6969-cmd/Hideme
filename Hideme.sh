#!/bin/bash

def_mac_txt_path="$( [ -f "mac_addresses.txt" ] && echo "mac_addresses.txt" || echo "")" # Default MAC address text list path
def_host_txt_path="$( [ -f "host_names.txt" ] && echo "host_names.txt" || echo "")" # Default host name list path
def_ip_txt_path="$( [ -f "IP_addresses.txt" ] && echo "IP_addresses.txt" || echo "")"
active_interface="" # The running interface 

################### Functions #################  

find_active_interface(){ # NO IN or OUT
    #Find active interface
    interfaces=$(iwconfig 2>/dev/null | grep '^[a-zA-Z0-9]' | awk '{print $1}')
    for i in $interfaces; do
        status=$(iwconfig $i 2>/dev/null | grep 'ESSID' | awk '{print $1}')
        if [ -n "$status" ]; then
           active_interface="$status"
        fi
    done

    # Validation Check
    if [ -z $active_interface ]; then
        echo "No active WLAN interface found."
        exit 1
    fi
}

default_case(){
    
    # Check for repetitions 
    unique_elements=($(printf "%s\n" "$@" | sort -u))
    if [ ${#unique_elements[@]} -ne $# ]; then
        echo "Invalid input"
        exit 1
    fi

    if [ -z "$1" ]; then        
        change_mac "$active_interface" "def"
        change_ip "$active_interface" "def"
        cahnge_host "def"
    else

        while [ -n "$1" ]; do
            case "$1" in

                "-mac" )
                change_mac "$active_interface" "def"
                ;;

                "-ip" )
                change_ip "$active_interface" "def"
                ;;

                "-host" )
                cahnge_host "def"
                ;;

                *)
                echo "Invalid input"
                exit 1
                ;;
            esac
            shift
        done
    fi
    exit 0
}  

manual_case(){

    # Check for repetitions 
    unique_elements=($(printf "%s\n" "$@" | sort -u))
    if [ ${#unique_elements[@]} -ne $# ]; then
        echo "Invalid input (repetitions detected)"
        exit 1
    fi


    while [ -n "$2" ]; do
        case "$1" in 
            #manual MAC_address varieble 
            "-mac" )
            change_mac "$active_interface" "man" "$2" # Sending dyrecly the MAC address
            shift
            ;;

            "-ip" )
            change_ip "$active_interface" "man" "$2"
            shift
            ;;

            "-host" )
            echo -e "Changing host to: $2"
            shift
            ;;

            *)
            exit 1
        esac
        shift
    done
    exit 0
}

random(){ # $1(mode)/(user file) $2(txt file) OUT: random line

    if [[ "$1" = "def" ]]; then
        mac_list="$(cat "$2" 2>/dev/null)"
        else
            mac_list="$(cat "$1")"
    fi
    echo "$(echo "$mac_list" | shuf -n 1)"
}



delite_mac_address(){ #$1(MAC addres) $(the user list) OUT: MESSAGE
    list=$( [ -z "$2" ] && echo "$def_mac_txt_path" || echo "$1")
    sed -i "/$1/d" "$list"
    echo -e "--Address $1 has been deleted--\n\n\n\n"
}

change_mac() { # $1(active Wlan) $2(mode) $3(user mac address)

    case $2 in

        "def" )
        new_mac="$(random "def" "$def_mac_txt_path")"
        if [ -z "$new_mac" ]; then 
            echo -e "[ERROR] The file $def_mac_txt_path is missing" 
            exit 1
        fi
        ;;

        "man" )
        new_mac="$3"
        ;;
    esac

    # Spoof the address
    
    error_massage=$(sudo ifconfig "$1" down 2>&1 >/dev/null)
	error_massage+="$(sudo macchanger -m "$new_mac" "$1" 2>&1 )"
    failed="$?"
	error_massage+="$(sudo ifconfig "$1" up 2>&1 >/dev/null)"

    # Errors check
    if [ $failed -eq 0 ]; then 
        new_mac=$(ifconfig "$1" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
        echo -e "$1 Interface MAC address changed to: $new_mac"
            else
            # Casses of modes
            case "$2" in # Check the second variable 

                "def" ) # If $2 is -d, then we on defoult mode
                echo -e "Macchanger error: $error_massage\n"
                echo -n "The MAC address : $new_mac is invalid, Delit him [y/n]?"
                read -r answer 
	            if [ "$answer" = "y" ] ; then
		            delite_mac_address "$new_mac"
	            fi
                # Try again
                change_mac "$1" "$2" 
                ;;

                "man" )
                echo -e "$error_massage\n"
                ;;
            esac
    fi
}



change_ip(){ # $1(Wlan Interface) $2(mode) $3(ip)
    error_massage=""
    case $2 in

        "def" )
        new_ip="$(random "def" "$def_ip_txt_path")"
        if [ -z "$new_ip" ]; then 
            echo -e "[ERROR] The ip.txt file $def_ip_txt_path is missing" 
            exit 1
        fi
        ;;

        "man" )
        new_ip="$3"
        ;;
    esac

   # error_massage="$(sudo ifconfig "$1" down 2>&1 >/dev/null)"
	error_massage+="$(sudo ifconfig "$1" "$new_ip")"
    failed="$?"
	#error_massage+="$(sudo ifconfig "$1" up 2>&1 >/dev/null)"

    # Errors check
    if [ $failed -eq 0 ]; then 
        new_ip=$(ifconfig "$1" | awk '/inet / {print $2}')
        echo -e "$1 Interface IP address changed to: $new_ip"
            else
            # Casses of modes
            case "$2" in # Check the second variable 

                "def" ) # If $2 is -d, then we on defoult mode
                echo -e "$error_massage\n"
                echo -n -e "Failed to change the ip address to : $new_ip \nDo you want ot delite him before trying agin [y/n]?"
                read -r answer 
	            if [ "$answer" = "y" ] ; then
		           # delite_mac_address "$new_ip"
                   echo "Fuck you\n"
	            fi
                # Try again
                change_ip "$1" "$2" 
                ;;

                "man" )
                echo -e "$error_massage\n"
                ;;
            esac
    fi
}


cahnge_host(){
    echo -e "Changing the host name"
}


install_macchanger() {
    echo "Fuck it"
}

################### Main ######################

# Premmision check
if [ "$(id -u)" -ne 0 ]; then
	echo "Root premission required"
	exit 1
fi

# Macchanger installation check
if [ -z "$(which macchanger)" ]; then
    echo -e "You must have 'macchanger' installed to run this script, install now [y/n]?"
    read -r answer
    if [ "$answer" = "y" ]; then
        install_macchanger 
        else 
            echo -e "[ERROR] missing required software to execute the script \n\n"
            exit 1 
    fi
fi

# Find Wlan Interface
find_active_interface

echo -e "\n"
# Modes check
case "$1" in # $1(Mode) $2(Sub Mod) $3(Mac\host)

        # Defoult mode (use priset lists)
        "-d" )       
            if [ $# -lt 5 ]; then
                shift
                default_case "$@"  
            
            else 
                echo "[ERROR] -To many variables"
                exit 1
            fi
        ;;  

        # Manual input
        "-m" )
            if [ $# -lt 8 ] && [ $# -gt 2 ]; then
                shift
                manual_case "$@"  
                 echo "test"
            
            else 
                echo "[ERROR] Invalid input"
                exit 1
            fi
        ;;

        #Also change the Host name 
        *)
        echo -e "\n [ERROR] Invalid input"
        exit 5
        ;;
esac
exit 0

