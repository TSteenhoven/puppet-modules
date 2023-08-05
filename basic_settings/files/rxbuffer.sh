#!/bin/bash

# Set default values
INTERFACE=""

# Grab the command line arguments
while test -n "$1"; do
    case "$1" in
        -i)
            INTERFACE=$2
            shift
            ;;
        --interface)
            INTERFACE=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit 1;
            ;;
    esac
    shift
done

# Check if interface is empty
if [ "${INTERFACE}" = "" ]; then
    echo "Interface is empty"
    exit 1
fi

# Check if public interface is a bond
if [ -f "/proc/net/bonding/${INTERFACE}" ]; then
    # Try to get slaces from bond
    cat "/proc/net/bonding/${INTERFACE}" | grep 'Slave Interface' | cut -d ':' -f 2 | cut -d ' ' -f 2 | while read line; do
        # Set some values
        apply_buffer="0"
        buffer_filename="/tmp/interface_${line}_buffer"

        # Get status of the buffer
        if [ -f $buffer_filename ]; then
            result_temp_buffer=$(cat $buffer_filename)
            if [ "$result_temp_buffer" == "0" ]; then
                apply_buffer="1"
            fi
        else
            apply_buffer="1"
        fi

        # Check if we need to change buffer */
        if [ "$apply_buffer" == "1" ]; then
            # Set new buffer
            ethtool -G $line tx 4096
            status_buffer_one=$?

            # Check if command is finished successfully
            if [ $status_buffer_one -eq 0 ]; then
                # Set new buffer
                ethtool -G $line rx 4096
                status_buffer_two=$?

                # Check if command is finished successfully
                if [ $status_buffer_two -eq 0 ]; then
                    echo "1" > $buffer_filename
                else
                    echo "0" > $buffer_filename
                fi
            else
                echo "0" > $buffer_filename
            fi
        fi
    done;
else
    # Set some values
    apply_buffer="0"

    # Get status of the buffer
    if [ -f "/tmp/interface_${INTERFACE}_buffer" ]; then
        result_temp_buffer=$(cat "/tmp/interface_${INTERFACE}_buffer")
        if [ "$result_temp_buffer" == "0" ]; then
            apply_buffer="1"
        fi
    else
        apply_buffer="1"
    fi

    # Check if we need to change buffer */
    if [ "$apply_buffer" == "1" ]; then
        # Set new buffer
        ethtool -G $INTERFACE tx 4096
        status_buffer_one=$?

        # Check if command is finished successfully
        if [ $status_buffer_one -eq 0 ]; then
            # Set new buffer
            ethtool -G $INTERFACE rx 4096
            status_buffer_two=$?

            # Check if command is finished successfully
            if [ $status_buffer_two -eq 0 ]; then
                echo "1" > "/tmp/interface_${INTERFACE}_buffer"
            else
                echo "0" > "/tmp/interface_${INTERFACE}_buffer"
            fi
        else
            echo "0" > "/tmp/interface_${INTERFACE}_buffer"
        fi
    fi
fi